// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// Styling for a single banner. The host builds one of these per banner value.
///
/// Only `position`, `duration`, `frame.height`, `stacks`, `renderScale`,
/// `showAnimation`, and `showFrom` are consumed by the SDK's engine/layout. The
/// rest (`cornerRadius`, `fillColor`, `opacity`, `textColor`, `font`, `fontSize`)
/// are styling *hints* your `makeContent()` may honor — the SDK never draws the
/// banner itself — so they all have defaults.
public struct BannerProperties {
    public var cornerRadius: Double
    /// Banner size. Only `height` feeds the stacking math; `width` is a hint for
    /// your content. Use `.zero` for self-sizing content (falls back to a default
    /// stacking height).
    public var frame: CGSize
    public var fillColor: Color
    public var opacity: Double
    public var showAnimation: Animation?
    public var showFrom: Edge
    public var duration: Double
    public var textColor: Color
    public var fontSize: CGFloat?
    /// An explicit font for the banner's text. Takes precedence over `fontSize`
    /// when the host's content honors it. `nil` leaves the choice to the content.
    public var font: Font?
    /// Where the banner anchors on screen.
    public var position: BannerPosition
    /// Text announced to VoiceOver when the banner appears (and used as its
    /// accessibility label). `nil` = no announcement.
    public var accessibilityLabel: String?
    /// Render scale applied to the content on iOS. `nil` keeps the legacy device
    /// downscale (0.5 iPad / 0.4 iPhone) used by banners designed at tvOS size;
    /// set `1` for content laid out natively (e.g. ``GlassBanner``). On tvOS/macOS
    /// the default is `1`.
    public var renderScale: CGFloat?
    /// Whether this banner participates in the vertical pile at its `position`.
    ///
    /// Defaults to `false`: the banner is a **singleton** at its corner — enqueuing
    /// it replaces any banner already anchored there. Opt in with `true` (bottom
    /// anchors only) to let banners sharing a `position` stack and clear one at a
    /// time; top anchors never pile regardless.
    public var stacks: Bool

    public init(
        frame: CGSize,
        duration: Double,
        position: BannerPosition,
        cornerRadius: Double = 12,
        fillColor: Color = .clear,
        opacity: Double = 1,
        showAnimation: Animation? = .smooth,
        showFrom: Edge = .top,
        textColor: Color = .primary,
        fontSize: CGFloat? = nil,
        font: Font? = nil,
        renderScale: CGFloat? = nil,
        stacks: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.cornerRadius = cornerRadius
        self.frame = frame
        self.fillColor = fillColor
        self.opacity = opacity
        self.showAnimation = showAnimation
        self.showFrom = showFrom
        self.duration = duration
        self.position = position
        self.textColor = textColor
        self.fontSize = fontSize
        self.font = font
        self.renderScale = renderScale
        self.stacks = stacks
        self.accessibilityLabel = accessibilityLabel
    }
}
