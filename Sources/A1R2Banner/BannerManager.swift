// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// The banner engine: an observable queue with duplicate suppression, vertical
/// stacking, and timed auto-removal. Generic over the host's banner value.
///
/// Ported from the app's `BannerManager`: made generic over `Banner`,
/// `DDLogger` replaced by an injectable `log` closure, and the write-only
/// `playerErrorCount` dropped. The offset math is preserved byte-for-byte.
@MainActor
public final class BannerManager<Banner: BannerPresentable>: ObservableObject {
    @Published public private(set) var items: [BannerItem<Banner>] = []
    @Published public private(set) var lastRemovedID: UUID?

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private let log: (String) -> Void

    public init(log: @escaping (String) -> Void = { _ in }) {
        self.log = log
    }

    /// Enqueue a banner. Duplicates (by `Banner` identity) are suppressed.
    /// `duration` defaults to the banner's own `bannerProperties.duration`.
    public func enqueue(_ banner: Banner, duration: TimeInterval? = nil) {
        let isDuplicate = items.contains { $0.banner == banner }
        if isDuplicate {
            log("⚠️ Duplicate banner detected, skipping")
            return
        }

        let dur = duration ?? banner.bannerProperties.duration

        // Calculate offset for ALL banners including the new one.
        let totalBanners = items.count + 1
        let offsets = calculateOffsets(for: totalBanners)
        let bannerOffSet = offsets.last ?? 0

        let nextBanner = BannerItem(
            id: UUID(),
            when: Date(),
            banner: banner,
            duration: dur,
            offset: bannerOffSet
        )

        items.append(nextBanner)
        log("🇺🇸 Added banner: \(nextBanner.id) - Queue count: \(items.count)")

        let task = Task { [weak self] in
            guard let self else { return }
            await self.displayAndRemove(nextBanner)
            self.tasks.removeValue(forKey: nextBanner.id)
        }
        tasks[nextBanner.id] = task
    }

    private func calculateOffsets(for count: Int) -> [CGFloat] {
        let maxBanners = 9
        var offsets: [CGFloat] = []

        let validCount = min(count, maxBanners)

        for i in 1...validCount {
            let offset: CGFloat
            switch i {
            case 1: offset = 0
            case 2: offset = 120
            case 3: offset = 240
            case 4: offset = 360
            case 5: offset = 480
            case 6: offset = 600
            case 7: offset = 720
            case 8: offset = 840
            case 9: offset = 960
            default: offset = 0
            }
            let value = offset == 0 ? 0 : -offset
            offsets.append(value)
        }

        return offsets
    }

    private func displayAndRemove(_ banner: BannerItem<Banner>) async {
        let delay = banner.duration + 0.4
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        if let index = items.firstIndex(where: { $0.id == banner.id }) {
            removeAndRecalculate(at: index)
        }
    }

    private func removeAndRecalculate(at index: Int) {
        guard let removed = items[safe: index] else {
            log("Invalid index, no banner to remove.")
            return
        }

        tasks[removed.id]?.cancel()
        tasks.removeValue(forKey: removed.id)

        items.remove(at: index)
        log("🇺🇸 Removed banner \(removed.id) at index \(index). Remaining: \(items.count)")

        recalculateOffsets()
        lastRemovedID = removed.id
    }

    private func recalculateOffsets() {
        guard !items.isEmpty else { return }
        let offsets = calculateOffsets(for: items.count)
        for index in 0..<items.count {
            items[index].offset = offsets[safe: index] ?? 0
        }
    }
}
