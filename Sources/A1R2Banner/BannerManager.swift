// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// Tunable metrics for the vertical pile shared by all `BannerManager` instances.
/// (Kept outside the generic type — Swift forbids static stored properties there.)
enum BannerStackMetrics {
    /// Vertical gap (in the banner's own, unscaled points) between piled banners
    /// sharing a position.
    static let gap: CGFloat = 16
    /// Fallback height for self-sizing banners whose `frame.height` is 0
    /// (e.g. ``GlassBanner``), used only for stacking math.
    static let defaultHeight: CGFloat = 60
}

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

        // Singletons (the default, and every top-anchored banner) replace whatever
        // is already at their position — so nothing overlaps and nothing climbs
        // off-screen. Only opt-in bottom-anchored piles keep their siblings.
        if !effectivelyStacks(banner) {
            let position = banner.bannerProperties.position
            for victim in items where victim.banner.bannerProperties.position == position {
                tasks[victim.id]?.cancel()
                tasks.removeValue(forKey: victim.id)
            }
            items.removeAll { $0.banner.bannerProperties.position == position }
        }

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

    /// A banner piles only if it opts in AND sits at a bottom anchor. Top anchors
    /// never pile (they'd stack off-screen), so they're always singletons.
    private func effectivelyStacks(_ banner: Banner) -> Bool {
        let props = banner.bannerProperties
        return props.stacks && !props.position.isTopAnchored
    }

    private func recalculateOffsets() {
        guard !items.isEmpty else { return }
        // `items` is kept in enqueue (oldest-first) order. Walk it once, keeping a
        // per-position running total of the (height + gap) of the *piling* banners
        // below. Each sits above that total, so spacing tracks the actual banner
        // size. Singletons (default + all top anchors) are pinned at 0 and excluded.
        var cumulativeByPosition: [BannerPosition: CGFloat] = [:]
        for index in 0..<items.count {
            let banner = items[index].banner
            guard effectivelyStacks(banner) else {
                items[index].offset = 0
                continue
            }
            let props = banner.bannerProperties
            let cumulative = cumulativeByPosition[props.position, default: 0]
            items[index].offset = -cumulative      // bottom anchors stack upward, into view
            let height = props.frame.height > 0 ? props.frame.height : BannerStackMetrics.defaultHeight
            cumulativeByPosition[props.position] = cumulative + height + BannerStackMetrics.gap
        }
    }
}
