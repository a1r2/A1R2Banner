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
/// content to the requested corner with a fixed inset, **inside the safe area** —
/// so a top banner sits below the notch / Dynamic Island / title bar, and it
/// re-anchors correctly on rotation or window resize. On iOS the content is scaled
/// by `iOSScale` (default 0.5 iPad / 0.4 iPhone for tvOS-sized art; `GlassBanner`
/// uses 1).
public struct BannerView<Banner: BannerPresentable>: View {
    let banner: Banner
    /// Extra y-shift (unscaled points) used by the queue to stack piled banners.
    var stackOffset: CGFloat

    #if os(iOS)
    /// Retained for source compatibility. Layout is now unified and safe-area
    /// aware, so `.adaptive` and `.fixed` render identically; a banner attached
    /// as an `.overlay` on a bounded container hugs that container's corner either
    /// way.
    var placement: BannerPlacement

    public init(banner: Banner, placement: BannerPlacement = .adaptive, stackOffset: CGFloat = 0) {
        self.banner = banner
        self.placement = placement
        self.stackOffset = stackOffset
    }
    #else
    public init(banner: Banner, stackOffset: CGFloat = 0) {
        self.banner = banner
        self.stackOffset = stackOffset
    }
    #endif

    @State private var showBannerView = false
    @State private var dismissTask: Task<Void, Never>?

    private var props: BannerProperties { banner.bannerProperties }

    /// Fixed inset from the anchored edges.
    private let edgeInset: CGFloat = 20

    public var body: some View {
        ZStack {
            if showBannerView {
                banner.makeContent()
                    .scaleEffect(contentScale, anchor: anchorPoint)
                    .padding(edgeInset)
                    .offset(y: stackOffset * contentScale)
                    .transition(.move(edge: props.showFrom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .onAppear { showBanner() }
        .onDisappear {
            dismissTask?.cancel()
            dismissTask = nil
        }
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
        if let scale = props.iOSScale { return scale }
        return UIDevice.current.userInterfaceIdiom == .pad ? 0.5 : 0.4
        #else
        return props.iOSScale ?? 1
        #endif
    }

    private func showBanner() {
        withAnimation(props.showAnimation) {
            showBannerView = true
        }
        dismissBanner(with: props.showAnimation, after: props.duration)
    }

    private func dismissBanner(with animationType: Animation?, after delay: TimeInterval) {
        guard let animationType = animationType else { return }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(animationType) {
                showBannerView = false
            }
        }
    }
}
