// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI
#if os(iOS)
import UIKit
#endif

/// Renders one banner: content from `banner.makeContent()`, anchored per
/// `banner.bannerProperties.position`.
///
/// Layout is uniform across platforms: the view fills its container and pins the
/// content to the requested corner with a fixed inset, **inside the safe area**
/// (tvOS hugs the physical edge). It re-anchors on rotation / window resize. On
/// iOS the content is scaled by `renderScale` (default 0.5 iPad / 0.4 iPhone for
/// tvOS-sized art; `GlassBanner` uses 1). Honors Reduce Motion and posts a
/// VoiceOver announcement when `accessibilityLabel` is set.
public struct BannerView<Banner: BannerPresentable>: View {
    let banner: Banner
    /// Effective visible duration. `nil` uses `bannerProperties.duration`. The
    /// queue passes the per-enqueue override so the exit animation and the model
    /// removal share one clock.
    var duration: TimeInterval?
    /// Extra y-shift (unscaled points) used by the queue to stack piled banners.
    var stackOffset: CGFloat

    public init(banner: Banner, duration: TimeInterval? = nil, stackOffset: CGFloat = 0) {
        self.banner = banner
        self.duration = duration
        self.stackOffset = stackOffset
    }

    #if os(iOS)
    @available(*, deprecated, message: "Layout is unified and safe-area aware; placement no longer affects rendering. Use init(banner:duration:stackOffset:).")
    public init(banner: Banner, placement: BannerPlacement, duration: TimeInterval? = nil, stackOffset: CGFloat = 0) {
        self.init(banner: banner, duration: duration, stackOffset: stackOffset)
    }
    #endif

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showBannerView = false
    @State private var didStart = false
    @State private var dismissTask: Task<Void, Never>?

    private var props: BannerProperties { banner.bannerProperties }
    private var effectiveDuration: TimeInterval { duration ?? props.duration }

    /// Fixed inset from the anchored edges.
    private let edgeInset: CGFloat = 20

    public var body: some View {
        ZStack {
            if showBannerView {
                banner.makeContent()
                    .scaleEffect(contentScale, anchor: anchorPoint)
                    .padding(edgeInset)
                    .offset(y: stackOffset * contentScale)
                    .transition(transition)
                    .accessibilityLabelIfPresent(props.accessibilityLabel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        #if os(tvOS)
        // tvOS: hug the physical edges (like the shipping app). The title-safe
        // area here is large enough that respecting it strands banners far from
        // the corner. iOS/macOS keep the safe area (notch / Island / title bar).
        .ignoresSafeArea()
        #endif
        .onAppear {
            // Start the show/dismiss cycle once — not on every re-appear.
            guard !didStart else { return }
            didStart = true
            showBanner()
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    private var transition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: props.showFrom)
    }

    private var alignment: Alignment {
        switch props.position {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .topCenter: return .top
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        case .bottomCenter: return .bottom
        }
    }

    // Anchor the scaleEffect at the same corner so scaling doesn't drift it away.
    private var anchorPoint: UnitPoint {
        switch props.position {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .topCenter: return .top
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        case .bottomCenter: return .bottom
        }
    }

    private var contentScale: CGFloat {
        #if os(iOS)
        if let scale = props.renderScale { return scale }
        return UIDevice.current.userInterfaceIdiom == .pad ? 0.5 : 0.4
        #else
        return props.renderScale ?? 1
        #endif
    }

    private func showBanner() {
        let animation = reduceMotion ? nil : props.showAnimation
        withAnimation(animation) {
            showBannerView = true
        }
        if let label = props.accessibilityLabel {
            AccessibilityNotification.Announcement(label).post()
        }
        dismissBanner(with: animation, after: effectiveDuration)
    }

    private func dismissBanner(with animationType: Animation?, after delay: TimeInterval) {
        guard delay.isFinite else { return }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(animationType) {
                showBannerView = false
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func accessibilityLabelIfPresent(_ label: String?) -> some View {
        if let label {
            self.accessibilityElement(children: .ignore).accessibilityLabel(Text(label))
        } else {
            self
        }
    }
}
