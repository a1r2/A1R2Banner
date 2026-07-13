// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


/// How a banner anchors itself on iOS.
///
/// - `adaptive`: orientation/idiom-aware screen-geometry padding. Right for a
///   full-screen overlay (the queue attached via `.bannerOverlay`).
/// - `fixed`: fixed corner insets, like tvOS. Right for a banner rendered inside
///   a bounded container (e.g. a card or tile) that should hug its corner.
///
/// On tvOS placement is always fixed; this only affects iOS.
public enum BannerPlacement: Sendable, Hashable {
    case adaptive
    case fixed
}
