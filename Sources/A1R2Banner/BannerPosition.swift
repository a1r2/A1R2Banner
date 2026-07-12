// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// Where a banner anchors on screen. Replaces the implicit corner grouping that
/// used to be switched on the app's banner enum.
public enum BannerPosition: Sendable, Hashable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case bottomCenter
}
