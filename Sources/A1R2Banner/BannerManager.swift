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
    /// Default vertical gap between piled banners sharing a position. Overridable
    /// per `BannerManager` via `init(stackGap:)`.
    static let gap: CGFloat = 16
    /// Fallback height for self-sizing banners whose `frame.height` is 0
    /// (e.g. ``GlassBanner``), used only for stacking math.
    static let defaultHeight: CGFloat = 60
    /// Most banners a single position may pile before the oldest is evicted, so a
    /// pile can never grow off-screen.
    static let maxPerPosition = 9
    /// Grace period after a banner's duration before the model row is removed,
    /// giving the exit transition time to finish. Keep ≥ the exit animation.
    static let exitGrace: TimeInterval = 0.4
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
    private let stackGap: CGFloat

    /// - Parameter stackGap: vertical gap between piled banners (default 16 pt).
    public init(stackGap: CGFloat = 16, log: @escaping (String) -> Void = { _ in }) {
        self.stackGap = stackGap
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
        let position = banner.bannerProperties.position

        if effectivelyStacks(banner) {
            // Cap the pile: evict the oldest sibling so a stack can't grow off-screen.
            let siblings = items.filter {
                $0.banner.bannerProperties.position == position && effectivelyStacks($0.banner)
            }
            if siblings.count >= BannerStackMetrics.maxPerPosition, let oldest = siblings.first {
                evict(oldest.id)
            }
        } else {
            // Singleton (the default, and every top-anchored banner): replace whatever
            // is already at this position — no overlap, nothing climbs off-screen.
            for victimID in items.filter({ $0.banner.bannerProperties.position == position }).map(\.id) {
                evict(victimID)
            }
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
        let lastID = items.last?.id
        items.removeAll()
        if let lastID { lastRemovedID = lastID }
    }

    /// Dismiss a single queued banner early (cancels its timer, animates the pile).
    public func dismiss(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        removeAndRecalculate(at: index)
    }

    // Cancel a banner's timer and remove it without animating the survivors
    // (used for silent replacement / cap eviction). Records `lastRemovedID`.
    private func evict(_ id: UUID) {
        tasks[id]?.cancel()
        tasks.removeValue(forKey: id)
        items.removeAll { $0.id == id }
        lastRemovedID = id
    }

    private func displayAndRemove(_ banner: BannerItem<Banner>) async {
        let delay = banner.duration + BannerStackMetrics.exitGrace
        guard delay.isFinite else { return }
        try? await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
        guard !Task.isCancelled else { return }

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

        // Animate so surviving stacked banners slide into their new offset.
        withAnimation(removed.banner.bannerProperties.showAnimation) {
            items.remove(at: index)
            recalculateOffsets()
        }
        log("🇺🇸 Removed banner \(removed.id) at index \(index). Remaining: \(items.count)")

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
            cumulativeByPosition[props.position] = cumulative + height + stackGap
        }
    }
}
