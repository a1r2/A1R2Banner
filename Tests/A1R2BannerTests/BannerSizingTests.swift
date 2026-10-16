import XCTest
import SwiftUI
@testable import A1R2Banner

final class BannerSizingTests: XCTestCase {
    func testFootprintAcrossArbitraryRegionsAndResizing() {
        for width: CGFloat in [0, 1, 12, 44, 120, 240, 360, 560, 800, 1920, 10000, 240, 1] {
            for height: CGFloat in [0, 1, 20, 80, 300, 1200] {
                for scale: CGFloat in [0.4, 0.5, 1, 2] {
                    let region = ProposedViewSize(width: width, height: height)
                    let limit = BannerSizing.limit(region, maximumWidth: 560)
                    let size = BannerSizing.footprint(CGSize(width: 900, height: 300), limit: limit, scale: scale)
                    XCTAssertTrue(size.width.isFinite && size.height.isFinite)
                    XCTAssertGreaterThanOrEqual(size.width, 0)
                    XCTAssertGreaterThanOrEqual(size.height, 0)
                    XCTAssertLessThanOrEqual(size.width, min(width, 560))
                    XCTAssertLessThanOrEqual(size.height, height)
                    XCTAssertEqual(size, BannerSizing.footprint(CGSize(width: 900, height: 300), limit: limit, scale: scale))
                }
            }
        }
    }

    func testUnspecifiedInfiniteAndInvalidInputs() {
        for value: CGFloat? in [nil, .infinity, -.infinity, .nan, -20] {
            let limit = BannerSizing.limit(ProposedViewSize(width: value, height: value), maximumWidth: .nan)
            XCTAssertTrue(limit.width.isFinite && limit.height.isFinite)
            XCTAssertGreaterThanOrEqual(limit.width, 0)
            XCTAssertGreaterThanOrEqual(limit.height, 0)
            XCTAssertLessThanOrEqual(limit.width, 560)
        }
        for value: CGFloat? in [nil, 0, -1, .nan, .infinity] {
            XCTAssertEqual(BannerSizing.scale(value), 1)
        }
        XCTAssertEqual(BannerSizing.scale(0.4), 0.4)
        for value: CGFloat in [0.00001, 0.005, 1000] {
            XCTAssertEqual(BannerSizing.scale(value), value, "explicit positive artwork scales must not silently become native size")
        }
    }

    func testExplicitScaleHasMeasuredFootprint() {
        let limit = BannerSizing.limit(ProposedViewSize(width: 300, height: 100), maximumWidth: 560)
        XCTAssertEqual(BannerSizing.footprint(CGSize(width: 400, height: 100), limit: limit, scale: 0.5),
                       CGSize(width: 200, height: 50))
    }

    @MainActor
    func testForegroundDefaultsAndOverrides() {
        let properties = BannerProperties(frame: .zero, duration: 1, position: .topCenter)
        XCTAssertEqual(properties.textColor, .white)
        XCTAssertNil(properties.renderScale)
        XCTAssertEqual(properties.maximumWidth, 560)
        let legacyProperties: (CGSize, Double, BannerPosition, Double, Color, Double, Animation?, Edge, Color, CGFloat?, Font?, CGFloat?, Bool, String?) -> BannerProperties = BannerProperties.init
        XCTAssertEqual(legacyProperties(.zero, 1, .topCenter, 12, .clear, 1, nil, .top, .white, nil, nil, nil, false, nil).maximumWidth, 560)
        let legacyGlass: (String, String?, String?, Color, BannerPosition, TimeInterval) -> GlassBanner = GlassBanner.init
        XCTAssertEqual(legacyGlass("Legacy", nil, nil, .blue, .topCenter, 3).textColor, .white)
        XCTAssertEqual(BannerProperties(frame: .zero, duration: 1, position: .topCenter, maximumWidth: 240).maximumWidth, 240)
        XCTAssertEqual(GlassBanner(title: "Default").textColor, .white)
        XCTAssertEqual(GlassBanner(title: "Override", textColor: .orange).bannerProperties.textColor, .orange)
        XCTAssertEqual(BannerProperties(frame: .zero, duration: 1, position: .topCenter, textColor: .green).textColor, .green)
    }
}
