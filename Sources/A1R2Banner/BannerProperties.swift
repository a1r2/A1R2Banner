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
/// `position` makes the on-screen anchor explicit (it used to be inferred from
/// the app's banner enum).
public struct BannerProperties {
    public var cornerRadius: Double
    public var frame: (width: CGFloat, height: CGFloat)
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
    /// Whether this banner participates in the vertical pile at its `position`.
    ///
    /// When `true` (default) banners sharing a `position` stack upward and clear
    /// one at a time (the classic bottom-trailing "pile and disappear"). When
    /// `false` the banner is a pinned singleton at its corner: it never offsets
    /// and never pushes — nor is pushed by — other banners.
    public var stacks: Bool

    public init(
        cornerRadius: Double,
        frame: (width: CGFloat, height: CGFloat),
        fillColor: Color,
        opacity: Double,
        showAnimation: Animation?,
        showFrom: Edge,
        duration: Double,
        position: BannerPosition,
        textColor: Color = .white,
        fontSize: CGFloat? = nil,
        font: Font? = nil,
        stacks: Bool = true
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
        self.stacks = stacks
    }
}
