// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// Renders one banner: content from `banner.makeContent()`, anchored per
/// `banner.bannerProperties.position`.
///
/// The host defines the usable region. Content is measured inside it, with a
/// bounded preferred width; no device or screen dimensions participate in layout.
/// Safe-area policy belongs to the host. Honors Reduce Motion and VoiceOver.
public struct BannerView<Banner: BannerPresentable>: View {
    let banner: Banner
    /// Effective visible duration. `nil` uses `bannerProperties.duration`. The
    /// queue passes the per-enqueue override so the exit animation and the model
    /// removal share one clock.
    var duration: TimeInterval?
    /// Legacy stacking reservation in host points, clamped to the host height.
    /// Manager overlays instead stack using measured content heights.
    var stackOffset: CGFloat

    public init(banner: Banner, duration: TimeInterval? = nil, stackOffset: CGFloat = 0) {
        self.banner = banner
        self.duration = duration
        self.stackOffset = stackOffset
    }

    #if os(iOS)
    @available(*, deprecated, message: "Layout uses the host region; placement no longer affects rendering. Use init(banner:duration:stackOffset:).")
    public init(banner: Banner, placement: BannerPlacement, duration: TimeInterval? = nil, stackOffset: CGFloat = 0) {
        self.init(banner: banner, duration: duration, stackOffset: stackOffset)
    }
    #endif

    public var body: some View {
        BannerRegionLayout(position: banner.bannerProperties.position, offset: stackOffset) {
            BannerPresentation(banner: banner, duration: duration)
        }
        .clipped()
    }
}

/// Intrinsic banner surface, shared by direct rendering and measured stacks.
struct BannerPresentation<Banner: BannerPresentable>: View {
    let banner: Banner
    var duration: TimeInterval?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showBannerView = false
    @State private var didStart = false
    @State private var dismissTask: Task<Void, Never>?

    private var props: BannerProperties { banner.bannerProperties }
    private var effectiveDuration: TimeInterval { duration ?? props.duration }

    var body: some View {
        ZStack {
            if showBannerView {
                BannerContentLayout(maximumWidth: props.maximumWidth, scale: scale) {
                    banner.makeContent()
                        .scaleEffect(scale, anchor: .topLeading)
                }
                .clipped()
                .contentShape(Rectangle())
                .transition(reduceMotion ? .opacity : .move(edge: props.showFrom))
                .accessibilityLabelIfPresent(props.accessibilityLabel)
            }
        }
        // Bound both drawing and interaction during the slide transition, while
        // leaving the surrounding overlay's empty space available to the host.
        .clipped()
        .contentShape(Rectangle())
        .onAppear {
            guard !didStart else { return }
            didStart = true
            showBanner()
        }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
    }

    private var scale: CGFloat { BannerSizing.scale(props.renderScale) }

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
