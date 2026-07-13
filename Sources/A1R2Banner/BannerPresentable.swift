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
///
/// Only `makeContent()` and `bannerProperties` are main-actor isolated, so a host
/// type's `Hashable`/`Equatable` conformance stays nonisolated. `Content` lets a
/// conformer return a concrete view (no forced `AnyView` erasure) — but returning
/// `AnyView` still satisfies it.
public protocol BannerPresentable: Hashable {
    associatedtype Content: View
    @MainActor var bannerProperties: BannerProperties { get }
    @MainActor func makeContent() -> Content
}
