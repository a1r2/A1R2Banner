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
/// The SDK consumes timing, positioning, maximumWidth and explicit renderScale.
/// Other styling fields are hints owned by custom content. Built-in glass content
/// honors its own semantic foreground color, defaulting to white.
public struct BannerProperties {
    public var cornerRadius: Double
    /// Legacy size hint for custom content. The renderer measures actual content
    /// instead of forcing this frame. Height remains in the manager's internal
    /// offset estimates for compatibility; it no longer controls visible stacking.
    public var frame: CGSize
    public var fillColor: Color
    public var opacity: Double
    public var showAnimation: Animation?
    public var showFrom: Edge
    public var duration: Double
    /// Default foreground hint for custom content; explicit child styles win.
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
    /// Optional explicit art scale. `nil` means native size on every platform.
    /// Behavioral change: `nil` formerly selected 0.4 on iPhone / 0.5 on iPad.
    /// Measurement accounts for this transform. Prefer native, wrapping content;
    /// explicit scaling also scales text and is intended for legacy artwork.
    /// Positive finite values are honored; other values fall back to 1.
    public var renderScale: CGFloat?
    /// Preferred upper bound in host points (default 560). The parent can always
    /// offer less. Does not force short intrinsic content to expand.
    /// This is a content-design cap, independent of device or screen dimensions.
    public var maximumWidth: CGFloat
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
        textColor: Color = .white,
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
        self.maximumWidth = 560
    }

    /// Additive sizing overload; the original initializer signature remains valid.
    public init(
        frame: CGSize,
        duration: Double,
        position: BannerPosition,
        cornerRadius: Double = 12,
        fillColor: Color = .clear,
        opacity: Double = 1,
        showAnimation: Animation? = .smooth,
        showFrom: Edge = .top,
        textColor: Color = .white,
        fontSize: CGFloat? = nil,
        font: Font? = nil,
        renderScale: CGFloat? = nil,
        stacks: Bool = false,
        accessibilityLabel: String? = nil,
        maximumWidth: CGFloat
    ) {
        self.init(frame: frame, duration: duration, position: position,
                  cornerRadius: cornerRadius, fillColor: fillColor, opacity: opacity,
                  showAnimation: showAnimation, showFrom: showFrom, textColor: textColor,
                  fontSize: fontSize, font: font, renderScale: renderScale, stacks: stacks,
                  accessibilityLabel: accessibilityLabel)
        self.maximumWidth = maximumWidth
    }
}
