// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// A batteries-included, gorgeous-by-default banner built on Apple's Liquid Glass.
///
/// Drop it straight into a `BannerManager<GlassBanner>` — no host type, no content
/// view, no styling:
///
/// ```swift
/// let banners = BannerManager<GlassBanner>()
/// banners.enqueue(GlassBanner(title: "Saved to Favorites", systemImage: "star.fill", tint: .yellow))
/// ```
///
/// It renders a Liquid Glass capsule that morphs open from the top (Dynamic-Island
/// style on iPhone), refracting whatever is behind it. Existing hosts that keep
/// their own banner type can reuse the look via ``GlassBannerContent`` from
/// `makeContent()` without adopting this value type.
public struct GlassBanner: BannerPresentable {
    public let title: String
    public let subtitle: String?
    public let systemImage: String?
    public let tint: Color
    public let position: BannerPosition
    public let duration: TimeInterval

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        tint: Color = .accentColor,
        position: BannerPosition = .topCenter,
        duration: TimeInterval = 3
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.position = position
        self.duration = duration
    }

    public var bannerProperties: BannerProperties {
        BannerProperties(
            frame: CGSize(width: 0, height: 64),  // content self-sizes; height feeds stacking math
            duration: duration,
            position: position,
            cornerRadius: 28,
            fillColor: tint,
            showAnimation: .smooth(duration: 0.4),
            showFrom: .top,
            renderScale: 1,   // laid out natively for iOS — no legacy downscale
            stacks: false,    // an Island-style notice is a singleton — latest replaces
            accessibilityLabel: [title, subtitle].compactMap { $0 }.joined(separator: ", ")
        )
    }

    public func makeContent() -> GlassBannerContent {
        GlassBannerContent(banner: self)
    }
}
