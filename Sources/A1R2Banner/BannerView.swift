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

/// Renders one banner: content from `banner.makeContent()`, styling and anchor
/// from `banner.bannerProperties`. iOS scales down (0.5 iPad / 0.4 iPhone) and
/// anchors at the banner's corner; tvOS uses fixed corner insets.
public struct BannerView<Banner: BannerPresentable>: View {
    let banner: Banner
    #if os(iOS)
    var geometry: GeometryProxy?
    var placement: BannerPlacement
    public init(banner: Banner, geometry: GeometryProxy? = nil, placement: BannerPlacement = .adaptive) {
        self.banner = banner
        self.geometry = geometry
        self.placement = placement
    }
    #else
    public init(banner: Banner) {
        self.banner = banner
    }
    #endif
    @State private var showBannerView = false
    @State private var dismissTask: Task<Void, Never>?

    public var body: some View {
        content
            .onAppear { showBanner() }
            .onDisappear {
                dismissTask?.cancel()
                dismissTask = nil
            }
    }

    private var props: BannerProperties { banner.bannerProperties }

    @ViewBuilder
    private var content: some View {
        #if os(iOS)
        if placement == .fixed {
            // Fixed corner insets (like tvOS). Meant to be attached as an `.overlay`
            // on a bounded container (e.g. a card or tile) so it hugs THAT
            // container's corner. It deliberately does not ignore safe area or force
            // a screen-sized frame — the overlay bounds it.
            ZStack {
                if showBannerView {
                    banner.makeContent()
                        .applyBannerModifier(position: props.position, showFrom: props.showFrom)
                        .scaleEffect(bannerScale, anchor: bannerAnchorPoint)
                }
            }
        } else {
            Group {
                if let geometry = geometry {
                    ZStack {
                        if showBannerView {
                            banner.makeContent()
                                .applyBannerModifier(position: props.position, showFrom: props.showFrom, geometry: geometry)
                                .scaleEffect(bannerScale, anchor: bannerAnchorPoint)
                        }
                    }
                } else {
                    GeometryReader { internalGeometry in
                        ZStack {
                            if showBannerView {
                                banner.makeContent()
                                    .applyBannerModifier(position: props.position, showFrom: props.showFrom, geometry: internalGeometry)
                                    .scaleEffect(bannerScale, anchor: bannerAnchorPoint)
                            }
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
        }
        #else
        ZStack {
            if showBannerView {
                banner.makeContent()
                    .applyBannerModifier(position: props.position, showFrom: props.showFrom)
            }
        }
        .edgesIgnoringSafeArea(.all)
        #endif
    }

    #if os(iOS)
    // Anchor the scaleEffect at the banner's corner so it stays put when scaled.
    private var bannerAnchorPoint: UnitPoint {
        switch props.position {
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .topLeading: return .topLeading
        case .bottomTrailing: return .bottomTrailing
        case .bottomCenter: return .bottom
        case .topCenter: return .top
        }
    }

    private var bannerScale: CGFloat {
        if let scale = props.iOSScale { return scale }
        return UIDevice.current.userInterfaceIdiom == .pad ? 0.5 : 0.4
    }
    #endif

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
