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
    var pos: BannerPosition = .bottomTrailing   // bottom anchor: can pile
    var stacks: Bool = true
    var height: CGFloat = 40

    static func == (l: StubBanner, r: StubBanner) -> Bool { l.key == r.key }
    func hash(into h: inout Hasher) { h.combine(key) }

    var bannerProperties: BannerProperties {
        BannerProperties(frame: CGSize(width: 100, height: height), duration: dur, position: pos,
                         cornerRadius: 10, fillColor: .red, showAnimation: nil,
                         showFrom: .trailing, stacks: stacks)
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
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .bottomTrailing))
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .bottomLeading))
        m.enqueue(StubBanner(key: "c", dur: 60, pos: .bottomTrailing))
        XCTAssertEqual(offset(m, "a"), 0)
        XCTAssertEqual(offset(m, "c"), -(40 + BannerStackMetrics.gap), "second banner at the SAME position stacks")
        XCTAssertEqual(offset(m, "b"), 0, "the sole banner at its own position stays put")
    }

    func testStacksDefaultsToFalseInBannerProperties() {
        let props = BannerProperties(frame: CGSize(width: 10, height: 10), duration: 1, position: .bottomTrailing)
        XCTAssertFalse(props.stacks, "banners are singletons unless the host opts into piling")
    }

    func testTopAnchoredNeverPiles() {
        let m = BannerManager<StubBanner>()
        // Both opt into stacking, but a top anchor must never pile.
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .topTrailing))
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .topTrailing))
        XCTAssertEqual(m.items.count, 1, "top anchors never pile — the newer one replaces")
        XCTAssertEqual(m.items[0].banner.key, "b")
        XCTAssertEqual(offset(m, "b"), 0)
    }

    func testSingletonReplacesOthersAtSamePosition() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .bottomTrailing))               // piles
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .bottomTrailing, stacks: false)) // singleton → replaces
        XCTAssertEqual(m.items.count, 1)
        XCTAssertEqual(m.items[0].banner.key, "b")
        XCTAssertEqual(offset(m, "b"), 0, "a singleton replaces whatever shared its position")
    }

    func testReplaceOnlyAffectsSamePosition() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .topTrailing))
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .topLeading))
        XCTAssertEqual(m.items.count, 2, "a singleton only replaces banners sharing its position")
    }

    func testRemovalRecalculatesOffsetsPerPosition() async {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "short", dur: 0.05, pos: .bottomTrailing))
        m.enqueue(StubBanner(key: "long", dur: 60, pos: .bottomTrailing))
        m.enqueue(StubBanner(key: "other", dur: 60, pos: .bottomLeading))
        XCTAssertEqual(offset(m, "long"), -(40 + BannerStackMetrics.gap))

        let deadline = Date().addingTimeInterval(2)
        while offset(m, "short") != nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        XCTAssertEqual(offset(m, "long"), 0, "remaining banner becomes first at its position after a removal")
        XCTAssertEqual(offset(m, "other"), 0, "untouched position keeps its offset")
    }

    // MARK: - Hardening, cap, replace, dismiss

    func testNegativeDurationDoesNotCrashAndRemovesPromptly() async {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "neg", dur: 5), duration: -1)   // would trap UInt64(negative) unclamped
        let deadline = Date().addingTimeInterval(2)
        while !m.items.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(m.items.isEmpty, "clamped negative duration removes promptly instead of trapping")
    }

    func testEnqueueDurationOverrideStoredOnItem() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 3), duration: 10)
        XCTAssertEqual(m.items[0].duration, 10, "the override reaches the item (and thus the view clock)")
    }

    func testPileIsCappedAndEvictsOldest() {
        let m = BannerManager<StubBanner>()
        for i in 0..<12 { m.enqueue(StubBanner(key: "b\(i)", dur: 60, pos: .bottomTrailing)) }
        XCTAssertEqual(m.items.count, BannerStackMetrics.maxPerPosition, "pile is capped")
        XCTAssertEqual(m.items.first?.banner.key, "b3", "oldest siblings were evicted (0,1,2 gone)")
        XCTAssertEqual(m.items.last?.offset,
                       -CGFloat(BannerStackMetrics.maxPerPosition - 1) * (40 + BannerStackMetrics.gap))
    }

    func testDismissByIdRemovesAndRecords() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60))
        m.enqueue(StubBanner(key: "b", dur: 60))
        let firstID = m.items[0].id
        m.dismiss(id: firstID)
        XCTAssertEqual(m.items.count, 1)
        XCTAssertEqual(m.items.first?.banner.key, "b")
        XCTAssertEqual(m.lastRemovedID, firstID)
    }

    func testSingletonReplaceRecordsLastRemovedID() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .bottomCenter, stacks: false))
        let aID = m.items[0].id
        m.enqueue(StubBanner(key: "b", dur: 60, pos: .bottomCenter, stacks: false))
        XCTAssertEqual(m.items.count, 1)
        XCTAssertEqual(m.lastRemovedID, aID, "the replaced banner is reported via lastRemovedID")
    }

    func testClearRecordsLastRemovedID() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60))
        m.enqueue(StubBanner(key: "b", dur: 60))
        let lastID = m.items.last?.id
        m.clear()
        XCTAssertEqual(m.lastRemovedID, lastID)
    }

    func testRemovingMiddleOfPileCollapsesUpperBanner() async {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60, pos: .bottomTrailing))
        m.enqueue(StubBanner(key: "b", dur: 0.05, pos: .bottomTrailing))
        m.enqueue(StubBanner(key: "c", dur: 60, pos: .bottomTrailing))
        XCTAssertEqual(offset(m, "c"), -2 * (40 + BannerStackMetrics.gap))

        let deadline = Date().addingTimeInterval(2)
        while offset(m, "b") != nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        XCTAssertEqual(offset(m, "a"), 0)
        XCTAssertEqual(offset(m, "c"), -(40 + BannerStackMetrics.gap), "upper banner collapses into the freed slot")
    }

    func testDuplicateDoesNotReplaceOrResetOriginal() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "x", dur: 60, pos: .bottomCenter, stacks: false))
        let originalID = m.items[0].id
        // Same identity (key "x") at a different position — must be suppressed as a
        // duplicate BEFORE any replace logic runs.
        m.enqueue(StubBanner(key: "x", dur: 60, pos: .topCenter, stacks: false))
        XCTAssertEqual(m.items.count, 1)
        XCTAssertEqual(m.items[0].id, originalID, "duplicate is dropped, original untouched")
    }

    func testBottomSingletonReplaceLeavesOtherBottomPileIntact() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "p1", dur: 60, pos: .bottomLeading))
        m.enqueue(StubBanner(key: "p2", dur: 60, pos: .bottomLeading))
        m.enqueue(StubBanner(key: "s", dur: 60, pos: .bottomTrailing, stacks: false))
        XCTAssertEqual(m.items.filter { $0.banner.bannerProperties.position == .bottomLeading }.count, 2,
                       "a singleton at one bottom corner leaves another bottom pile intact")
    }
}
