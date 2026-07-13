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
/// Generic over the host's banner value: `DDLogger` is replaced by an injectable
/// `log` closure and any host-specific write-only counters are omitted. The
/// offset math is preserved byte-for-byte.
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

        let nextBanner = BannerItem(
            id: UUID(),
            when: Date(),
            banner: banner,
            duration: dur,
            offset: 0
        )

        items.append(nextBanner)
        // Offsets are scoped per position (and only among stacking banners), so
        // banners anchored to different corners never push one another.
        recalculateOffsets()
        log("🇺🇸 Added banner: \(nextBanner.id) - Queue count: \(items.count)")

        let task = Task { [weak self] in
            guard let self else { return }
            await self.displayAndRemove(nextBanner)
            self.tasks.removeValue(forKey: nextBanner.id)
        }
        tasks[nextBanner.id] = task
    }

    /// Dismiss every queued banner immediately (e.g. on scene/route change).
    public func clear() {
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        items.removeAll()
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
        // `items` is kept in enqueue (oldest-first) order. Walk it once, keeping a
        // per-position running count of *stacking* banners: each stacking banner
        // gets the next offset in its own corner's pile; non-stacking banners are
        // pinned at 0 and excluded from every count.
        var stackCountByPosition: [BannerPosition: Int] = [:]
        for index in 0..<items.count {
            let props = items[index].banner.bannerProperties
            guard props.stacks else {
                items[index].offset = 0
                continue
            }
            let placeInPile = stackCountByPosition[props.position, default: 0]
            let offsets = calculateOffsets(for: placeInPile + 1)
            items[index].offset = offsets.last ?? 0
            stackCountByPosition[props.position] = placeInPile + 1
        }
    }
}
