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

    static func == (l: StubBanner, r: StubBanner) -> Bool { l.key == r.key }
    func hash(into h: inout Hasher) { h.combine(key) }

    var bannerProperties: BannerProperties {
        BannerProperties(cornerRadius: 10, frame: (100, 40), fillColor: .red,
                         opacity: 1, showAnimation: nil, showFrom: .trailing,
                         duration: dur, position: .topTrailing)
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

    func testSecondBannerStacksWith120Offset() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 5))
        m.enqueue(StubBanner(key: "b", dur: 5))
        XCTAssertEqual(m.items.count, 2)
        // enqueue assigns the last computed offset to the newest item.
        XCTAssertEqual(m.items[1].offset, -120)
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

    func testThirdBannerStacksAt240() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 60))
        m.enqueue(StubBanner(key: "b", dur: 60))
        m.enqueue(StubBanner(key: "c", dur: 60))
        XCTAssertEqual(m.items.count, 3)
        XCTAssertEqual(m.items[2].offset, -240)
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
}
