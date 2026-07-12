// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// A value the host provides to describe a banner: its styling and its content.
/// `Hashable` identity powers duplicate suppression in the queue.
@MainActor
public protocol BannerPresentable: Hashable {
    var bannerProperties: BannerProperties { get }
    func makeContent() -> AnyView
}
