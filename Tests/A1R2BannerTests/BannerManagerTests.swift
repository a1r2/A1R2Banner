// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import XCTest
import SwiftUI
@testable import A1R2Banner

private struct StubBanner: BannerPresentable {
    let key: String
    let dur: TimeInterval
    var pos: BannerPosition = .topTrailing
    var stacks: Bool = true
    var height: CGFloat = 40

    static func == (l: StubBanner, r: StubBanner) -> Bool { l.key == r.key }
    func hash(into h: inout Hasher) { h.combine(key) }

    var bannerProperties: BannerProperties {
        BannerProperties(cornerRadius: 10, frame: (100, height), fillColor: .red,
                         opacity: 1, showAnimation: nil, showFrom: .trailing,
                         duration: dur, position: pos, stacks: stacks)
    }
    func makeContent() -> AnyView { AnyView(Text(key)) }
}

@MainActor
final class BannerManagerTests: XCTestCase {

    func testEnqueueAddsBannerAndAssignsBaseOffset() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 5))
        XCTAssertEqual(m.items.count, 1)
        XCTAssertEqual(m.items[0].offset, 0)
    }

    func testDuplicateBannerIsSuppressed() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 5))
        m.enqueue(StubBanner(key: "a", dur: 5))
        XCTAssertEqual(m.items.count, 1, "same identity must not double-enqueue")
    }

    func testSecondBannerStacksByFirstHeightPlusGap() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 5))   // height 40
        m.enqueue(StubBanner(key: "b", dur: 5))
        XCTAssertEqual(m.items.count, 2)
        // The step is the banner below's height + the stack gap — not a magic ladder.
        XCTAssertEqual(m.items[1].offset, -(40 + BannerStackMetrics.gap))
    }

    func testTallerBannerBelowProducesLargerStep() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "tall", dur: 60, height: 100))
        m.enqueue(StubBanner(key: "b", dur: 60))
        XCTAssertEqual(m.items[1].offset, -(100 + BannerStackMetrics.gap),
                       "spacing tracks the actual height of the banner below")
    }

    func testDurationDefaultsFromBannerWhenNotOverridden() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 7))
        XCTAssertEqual(m.items[0].duration, 7, "duration falls back to the banner's own properties")
    }

    func testExplicitDurationOverridesBannerDuration() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 7), duration: 2)
        XCTAssertEqual(m.items[0].duration, 2)
    }

    func testThirdBannerStacksByTwiceHeightPlusGap() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60))
        m.enqueue(StubBanner(key: "b", dur: 60))
        m.enqueue(StubBanner(key: "c", dur: 60))
        XCTAssertEqual(m.items.count, 3)
        XCTAssertEqual(m.items[2].offset, -2 * (40 + BannerStackMetrics.gap))
    }

    func testBannerAutoRemovesAfterDuration() async {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 0.05))
        let id = m.items[0].id

        let deadline = Date().addingTimeInterval(2)
        while !m.items.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        XCTAssertTrue(m.items.isEmpty, "a banner auto-removes after its duration")
        XCTAssertEqual(m.lastRemovedID, id)
    }

    func testRemovalRecalculatesOffsets() async {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "short", dur: 0.05))
        m.enqueue(StubBanner(key: "long", dur: 60))
        XCTAssertEqual(m.items.count, 2)

        let deadline = Date().addingTimeInterval(2)
        while m.items.count > 1 && Date() < deadline {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        XCTAssertEqual(m.items.count, 1)
        XCTAssertEqual(m.items[0].banner.key, "long")
        XCTAssertEqual(m.items[0].offset, 0, "remaining banner's offset is recalculated after a removal")
    }

    func testClearRemovesAllBanners() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60))
        m.enqueue(StubBanner(key: "b", dur: 60))
        m.clear()
        XCTAssertTrue(m.items.isEmpty, "clear() dismisses every queued banner")
    }

    // MARK: - Per-position stacking

    private func offset(_ m: BannerManager<StubBanner>, _ key: String) -> CGFloat? {
        m.items.first { $0.banner.key == key }?.offset
    }

    func testBannersAtDifferentPositionsDoNotStack() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .topTrailing))
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .bottomLeading))
        XCTAssertEqual(m.items.count, 2)
        XCTAssertEqual(offset(m, "a"), 0)
        XCTAssertEqual(offset(m, "b"), 0, "a banner at a different position must not be pushed up by another")
    }

    func testStackingIsScopedPerPosition() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .topTrailing))
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .bottomLeading))
        m.enqueue(StubBanner(key: "c", dur: 60, pos: .topTrailing))
        XCTAssertEqual(offset(m, "a"), 0)
        XCTAssertEqual(offset(m, "c"), -(40 + BannerStackMetrics.gap), "second banner at the SAME position stacks")
        XCTAssertEqual(offset(m, "b"), 0, "the sole banner at its own position stays put")
    }

    func testNonStackingBannerStaysPinnedAtItsCorner() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .bottomTrailing))
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .bottomTrailing, stacks: false))
        XCTAssertEqual(offset(m, "a"), 0)
        XCTAssertEqual(offset(m, "b"), 0, "a non-stacking banner never offsets, even sharing a position")
    }

    func testNonStackingBannerDoesNotPushLaterStackingBanner() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "pinned", dur: 60, pos: .bottomTrailing, stacks: false))
        m.enqueue(StubBanner(key: "piled", dur: 60, pos: .bottomTrailing))
        XCTAssertEqual(offset(m, "piled"), 0, "a non-stacking banner is excluded from the pile count")
    }

    func testRemovalRecalculatesOffsetsPerPosition() async {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "short", dur: 0.05, pos: .topTrailing))
        m.enqueue(StubBanner(key: "long", dur: 60, pos: .topTrailing))
        m.enqueue(StubBanner(key: "other", dur: 60, pos: .bottomLeading))
        XCTAssertEqual(offset(m, "long"), -(40 + BannerStackMetrics.gap))

        let deadline = Date().addingTimeInterval(2)
        while offset(m, "short") != nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        XCTAssertEqual(offset(m, "long"), 0, "remaining banner becomes first at its position after a removal")
        XCTAssertEqual(offset(m, "other"), 0, "untouched position keeps its offset")
    }
}
