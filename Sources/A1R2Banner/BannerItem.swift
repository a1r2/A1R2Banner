// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import Foundation
import CoreGraphics

/// One enqueued banner. Generic over the host's banner value (was `BannerToQueue`).
public struct BannerItem<Banner: BannerPresentable>: Identifiable {
    public let id: UUID
    public let when: Date
    public let banner: Banner
    public let duration: TimeInterval
    public var offset: CGFloat

    init(id: UUID, when: Date, banner: Banner, duration: TimeInterval, offset: CGFloat = 0) {
        self.id = id
        self.when = when
        self.banner = banner
        self.duration = duration
        self.offset = offset
    }
}
