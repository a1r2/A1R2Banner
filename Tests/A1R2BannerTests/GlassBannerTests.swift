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

@MainActor
final class GlassBannerTests: XCTestCase {

    func testDefaultsToTopCenterSlot() {
        let b = GlassBanner(title: "Hi")
        XCTAssertEqual(b.bannerProperties.position, .topCenter,
                       "the drop-in glass banner defaults to the iPhone Dynamic-Island slot")
    }

    func testPositionCanBeOverridden() {
        let b = GlassBanner(title: "Hi", position: .topTrailing)
        XCTAssertEqual(b.bannerProperties.position, .topTrailing)
    }

    func testTintFlowsIntoProperties() {
        let b = GlassBanner(title: "Hi", tint: .yellow)
        XCTAssertEqual(b.bannerProperties.fillColor, Color.yellow)
    }

    func testDurationFlowsIntoProperties() {
        let b = GlassBanner(title: "Hi", duration: 7)
        XCTAssertEqual(b.bannerProperties.duration, 7)
    }

    func testEqualByContentForDedup() {
        let a = GlassBanner(title: "Saved", systemImage: "star.fill")
        let b = GlassBanner(title: "Saved", systemImage: "star.fill")
        XCTAssertEqual(a, b, "identical content dedups in the queue")
    }

    func testDifferentTitlesAreDistinct() {
        XCTAssertNotEqual(GlassBanner(title: "A"), GlassBanner(title: "B"))
    }

    func testSingletonNativeCapsuleContract() {
        let p = GlassBanner(title: "Hi", subtitle: "there").bannerProperties
        XCTAssertFalse(p.stacks, "an Island-style notice is a singleton")
        XCTAssertEqual(p.renderScale, 1, "renders at native iOS size")
        XCTAssertEqual(p.frame.width, 0)
        XCTAssertEqual(p.frame.height, 64, "self-sizes; height feeds stacking")
        XCTAssertEqual(p.cornerRadius, 28)
        XCTAssertEqual(p.position, .topCenter)
        XCTAssertEqual(p.accessibilityLabel, "Hi, there", "title + subtitle announced to VoiceOver")
    }

    func testDistinctByNonTitleFields() {
        XCTAssertNotEqual(GlassBanner(title: "S", tint: .red), GlassBanner(title: "S", tint: .blue))
        XCTAssertNotEqual(GlassBanner(title: "S", subtitle: "a"), GlassBanner(title: "S", subtitle: "b"))
        XCTAssertNotEqual(GlassBanner(title: "S", systemImage: "star"), GlassBanner(title: "S", systemImage: "bolt"))
        XCTAssertNotEqual(GlassBanner(title: "S", position: .topCenter), GlassBanner(title: "S", position: .topLeading))
        XCTAssertNotEqual(GlassBanner(title: "S", duration: 3), GlassBanner(title: "S", duration: 5))
    }
}
