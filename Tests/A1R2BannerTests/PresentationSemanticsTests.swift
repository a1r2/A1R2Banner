import XCTest
import SwiftUI
import A1R2Banner
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// This fixture intentionally uses only the pre-adaptive public API. Run the
/// identical file against d6807c2, 0.1.0 and the patch candidate.
struct MotionBanner: BannerPresentable {
    var position: BannerPosition
    var edge: Edge = .trailing
    var key = 0
    var height: CGFloat = 40
    var heightHint: CGFloat? = nil
    var scale: CGFloat = 1
    var stacks = false
    var duration: Double = 2.4
    var animation: Animation? = .linear(duration: 1.2)
    var bannerProperties: BannerProperties {
        BannerProperties(frame: CGSize(width: 80, height: heightHint ?? height), duration: duration,
                         position: position, showAnimation: animation, showFrom: edge,
                         renderScale: scale, stacks: stacks)
    }
    func makeContent() -> some View {
        Rectangle().fill(key == 0 ? Color.red : Color.blue).frame(width: 80, height: height)
            .onAppear { MotionMountClock.mounted = .now }
    }
}

@MainActor
final class PresentationSemanticsTests: XCTestCase {
    #if os(macOS)
    private var window: NSWindow?
    #else
    private var window: UIWindow?
    private var renderedRoot: UIView?
    #endif
    override func tearDown() async throws {
        #if os(macOS)
        window?.orderOut(nil)
        window?.contentView = nil
        #else
        window?.isHidden = true
        window?.rootViewController = nil
        renderedRoot = nil
        #endif
        window = nil
        try await super.tearDown()
    }

    func host<V: View>(_ view: V, width: CGFloat = 360) {
        #if os(macOS)
        _ = NSApplication.shared
        window?.orderOut(nil)
        let root = NSHostingView(rootView: Color.black.overlay { view }.frame(width: width, height: 300))
        root.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: 300), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = root
        self.window = window
        window.orderFrontRegardless()
        root.layoutSubtreeIfNeeded()
        #else
        window?.isHidden = true
        let controller = UIViewController()
        let hosting = UIHostingController(rootView: viewCanvas(view, width: width).ignoresSafeArea())
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        self.window = window
        window.makeKeyAndVisible()
        controller.addChild(hosting)
        controller.view.addSubview(hosting.view)
        hosting.view.bounds = CGRect(x: 0, y: 0, width: width, height: 300)
        hosting.view.layer.anchorPoint = .zero
        hosting.view.layer.position = .zero
        // Virtualize wide test hosts entirely inside the native window. UIKit
        // throttles offscreen composition, so resizing a window or letting the
        // tested region extend beyond it is not a valid animation-clock fixture.
        let viewportScale = min(1, controller.view.bounds.width / max(1, width), controller.view.bounds.height / 300)
        hosting.view.transform = CGAffineTransform(scaleX: viewportScale, y: viewportScale)
        hosting.didMove(toParent: controller)
        hosting.view.layoutIfNeeded()
        renderedRoot = hosting.view
        #endif
    }

    private func viewCanvas<V: View>(_ view: V, width: CGFloat) -> some View {
        Color.black.overlay { view }.frame(width: width, height: 300)
    }

    private func beginMotion<V: View>(_ view: V, width: CGFloat, name: String) async -> ContinuousClock.Instant {
        let visibility = MotionVisibility()
        host(MotionMount(visibility: visibility, content: view), width: width)
        try? await Task.sleep(for: .milliseconds(250))
        _ = try? capture(name + "-before")
        MotionMountClock.mounted = nil
        let requested = ContinuousClock.now
        visibility.visible = true
        for _ in 0..<200 {
            if let mounted = MotionMountClock.mounted {
                print("MOUNT \(name) request-to-content=\(requested.duration(to: mounted))")
                return mounted
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("fixture content did not mount")
        return .now
    }

    /// Raster bounds are observable presentation geometry, not SwiftUI model frames.
    func capture(_ name: String, blue: Bool = false) throws -> CGRect? {
        let image: CGImage
        #if os(macOS)
        let root = try XCTUnwrap(window?.contentView)
        root.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
        root.cacheDisplay(in: root.bounds, to: bitmap)
        image = try XCTUnwrap(bitmap.cgImage)
        let attachment = XCTAttachment(data: try XCTUnwrap(bitmap.representation(using: .png, properties: [:])), uniformTypeIdentifier: "public.png")
        #else
        let root = try XCTUnwrap(renderedRoot)
        root.layoutIfNeeded()
        let rendered = UIGraphicsImageRenderer(size: root.bounds.size).image { _ in root.drawHierarchy(in: root.bounds, afterScreenUpdates: false) }
        image = try XCTUnwrap(rendered.cgImage)
        let attachment = XCTAttachment(image: rendered)
        #endif
        if let directory = ProcessInfo.processInfo.environment["A1R2_PRESENTATION_OUTPUT"] {
            let folder = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            #if os(macOS)
            try bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name + ".png"))
            #else
            try rendered.pngData()?.write(to: folder.appendingPathComponent(name + ".png"))
            #endif
        }
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        bytes.withUnsafeMutableBytes { b in
            let c = CGContext(data: b.baseAddress, width: image.width, height: image.height,
                              bitsPerComponent: 8, bytesPerRow: image.width * 4,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var minX = image.width, minY = image.height, maxX = -1, maxY = -1
        for y in 0..<image.height { for x in 0..<image.width {
            let i = (y * image.width + x) * 4
            if blue ? (bytes[i+2] > 170 && bytes[i] < 80) : (bytes[i] > 170 && bytes[i+1] < 80 && bytes[i+2] < 80) {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        } }
        guard maxX >= 0 else { print("MOTION \(name) empty"); return nil }
        #if os(macOS)
        let scale = CGFloat(image.width) / (window?.contentView?.bounds.width ?? 1)
        #else
        let scale = CGFloat(image.width) / (renderedRoot?.bounds.width ?? 1)
        #endif
        let rect = CGRect(x: CGFloat(minX)/scale, y: CGFloat(minY)/scale,
                          width: CGFloat(maxX-minX+1)/scale, height: CGFloat(maxY-minY+1)/scale)
        print("MOTION \(name) \(rect)")
        return rect
    }

    func testInsertionAndRemovalTravelAcrossPositionsAndEdges() async throws {
        let positions: [BannerPosition] = [.topLeading, .topCenter, .topTrailing, .bottomLeading, .bottomCenter, .bottomTrailing]
        for (index, position) in positions.enumerated() {
            for edge: Edge in [.leading, .trailing, .top, .bottom] {
                // Both arbitrary host widths use the identical fixture across revisions.
                #if os(macOS)
                let width: CGFloat = index % 2 == 0 ? 240 : 800
                #else
                // Keep animated hierarchy capture inside the native compositor
                // viewport. 800-point hosts are covered by the macOS comparison;
                // UIKit culls/throttles their offscreen animation textures.
                let width: CGFloat = index % 2 == 0 ? 240 : 360
                #endif
                let start = await beginMotion(BannerView(banner: MotionBanner(position: position, edge: edge)), width: width, name: "\(position)-\(edge)")
                var captures: [CGRect?] = []
                for (label, time) in [("early",0.16),("mid",0.60),("rest",1.60),("exit-start",2.46),("exit-mid",3.00),("removed",5.20)] {
                    let target = start.advanced(by: .seconds(time))
                    try? await Task.sleep(until: target, clock: .continuous)
                    captures.append(try capture("\(position)-\(edge)-\(label)"))
                }
                let rest = try XCTUnwrap(captures[2])
                XCTAssertEqual(rest.width, 80, accuracy: 2)
                XCTAssertEqual(rest.height, 40, accuracy: 2)
                XCTAssertNotNil(captures[1], "the translated body must be visible midway through insertion")
                let mid = captures[1] ?? .zero
                XCTAssertNotNil(captures[4], "the translated body must be visible midway through removal")
                let exit = captures[4] ?? .zero
                // On edges that move into the host, the entire body must
                // translate outside its resting surface, rather than being wiped.
                let anchoredLeft = position == .topLeading || position == .bottomLeading
                let anchoredRight = position == .topTrailing || position == .bottomTrailing
                let anchoredTop = position == .topLeading || position == .topCenter || position == .topTrailing
                switch edge {
                case .leading:
                    XCTAssertLessThan(mid.midX, rest.midX - 2)
                    XCTAssertLessThan(exit.midX, rest.midX - 2)
                    if !anchoredLeft && width > 240 { XCTAssertGreaterThan(mid.width, 70); XCTAssertGreaterThan(exit.width, 70) }
                case .trailing:
                    XCTAssertGreaterThan(mid.midX, rest.midX + 2)
                    XCTAssertGreaterThan(exit.midX, rest.midX + 2)
                    if !anchoredRight && width > 240 { XCTAssertGreaterThan(mid.width, 70); XCTAssertGreaterThan(exit.width, 70) }
                case .top:
                    XCTAssertLessThan(mid.midY, rest.midY - 2)
                    XCTAssertLessThan(exit.midY, rest.midY - 2)
                    if !anchoredTop { XCTAssertGreaterThan(mid.height, 35); XCTAssertGreaterThan(exit.height, 35) }
                case .bottom:
                    XCTAssertGreaterThan(mid.midY, rest.midY + 2)
                    XCTAssertGreaterThan(exit.midY, rest.midY + 2)
                    if anchoredTop { XCTAssertGreaterThan(mid.height, 35); XCTAssertGreaterThan(exit.height, 35) }
                }
                func fraction(_ frame: CGRect) -> CGFloat {
                    switch edge {
                    case .leading: return (rest.maxX - frame.maxX) / (rest.width + 40)
                    case .trailing: return (frame.minX - rest.minX) / (rest.width + 40)
                    case .top: return (rest.maxY - frame.maxY) / (rest.height + 40)
                    case .bottom: return (frame.minY - rest.minY) / (rest.height + 40)
                    }
                }
                for (phase, frame) in zip(["insertion", "removal"], [mid, exit]) where frame != .zero {
                    // Raster capture cannot control SwiftUI's animation clock.
                    // Require an intermediate translation; direction and full
                    // visible-body assertions above distinguish moves from wipes.
                    XCTAssertGreaterThan(fraction(frame), 0.05, "\(position) \(edge) \(phase): expected an intermediate native move")
                    XCTAssertLessThan(fraction(frame), 0.95, "\(position) \(edge) \(phase): expected an intermediate native move")
                }
                XCTAssertNil(captures[5])
            }
        }
    }

    func testSignedStackOffsetAndRestingAnchors() async throws {
        for position: BannerPosition in [.topLeading, .topCenter, .topTrailing, .bottomLeading, .bottomCenter, .bottomTrailing] {
            for offset: CGFloat in [-30, 30] {
                host(BannerView(banner: MotionBanner(position: position, duration: .infinity, animation: nil), stackOffset: offset))
                try? await Task.sleep(for: .milliseconds(80))
                let rect = try XCTUnwrap(capture("offset-\(position)-\(offset)"))
                let top = [.topLeading, .topCenter, .topTrailing].contains(position)
                XCTAssertEqual(rect.minY, max(0, (top ? 20 : 240) + offset), accuracy: 2, "offset remains a signed y translation")
                if position == .topCenter || position == .bottomCenter { XCTAssertEqual(rect.midX, 180, accuracy: 2) }
            }
        }
    }

    func testStackExitReservesSpaceUntilQueueRemoval() async throws {
        let manager = BannerManager<MotionBanner>(stackGap: 7)
        let start = ContinuousClock.now
        manager.enqueue(MotionBanner(position: .bottomTrailing, height: 40, stacks: true,
                                     duration: 2, animation: .linear(duration: 0.15)))
        manager.enqueue(MotionBanner(position: .bottomTrailing, key: 1, height: 70, stacks: true,
                                     duration: .infinity, animation: nil))
        host(Color.clear.bannerOverlay(manager))
        try? await Task.sleep(until: start.advanced(by: .seconds(0.5)), clock: .continuous)
        let before = try XCTUnwrap(capture("exit-reservation-before", blue: true))
        try? await Task.sleep(until: start.advanced(by: .seconds(2.1)), clock: .continuous)
        let duringGrace = try XCTUnwrap(capture("exit-reservation-during-grace", blue: true))
        XCTAssertEqual(before.minY, duringGrace.minY, accuracy: 2,
                       "survivors must not jump before the queue removes the outgoing row")
        try? await Task.sleep(until: start.advanced(by: .seconds(2.8)), clock: .continuous)
        let removed = try XCTUnwrap(capture("exit-reservation-after", blue: true))
        XCTAssertGreaterThan(removed.minY, before.minY)
        manager.clear()
    }

    func testScaledSignedOffsetIsPresentationTranslation() async throws {
        for position: BannerPosition in [.topLeading, .topCenter, .topTrailing, .bottomLeading, .bottomCenter, .bottomTrailing] {
            for scale: CGFloat in [0.5, 2] {
                for offset: CGFloat in [-10, 10] {
                    host(BannerView(banner: MotionBanner(position: position, scale: scale, duration: .infinity, animation: nil), stackOffset: offset), width: 800)
                    try await Task.sleep(for: .milliseconds(100))
                    let rect = try XCTUnwrap(capture("scaled-offset-\(position)-\(scale)-\(offset)"))
                    let top = [.topLeading, .topCenter, .topTrailing].contains(position)
                    XCTAssertEqual(rect.minY, (top ? 20 : 280 - 40 * scale) + offset * scale, accuracy: 2)
                }
            }
        }
    }

    /// An intentional 0.1.0 improvement, separate from historical presentation.
    func testAdaptiveMeasuredStacksIgnoreInaccurateHeightHints() async throws {
        for heights: [CGFloat] in [[40, 40], [40, 70], [70, 40]] {
            let manager = BannerManager<MotionBanner>(stackGap: 7)
            manager.enqueue(MotionBanner(position: .bottomTrailing, height: heights[0], heightHint: 10, stacks: true, duration: .infinity, animation: nil))
            manager.enqueue(MotionBanner(position: .bottomTrailing, key: 1, height: heights[1], heightHint: 10, stacks: true, duration: .infinity, animation: nil))
            host(Color.clear.bannerOverlay(manager))
            try await Task.sleep(for: .milliseconds(150))
            let lower = try XCTUnwrap(capture("adaptive-lower-\(heights)"))
            let upper = try XCTUnwrap(capture("adaptive-upper-\(heights)", blue: true))
            XCTAssertEqual(lower.minY - upper.maxY, 7, accuracy: 2)
            XCTAssertEqual(lower.height, heights[0], accuracy: 2)
            XCTAssertEqual(upper.height, heights[1], accuracy: 2)
            manager.clear()
        }
    }

    #if os(iOS)
    func testDeprecatedPlacementHasNoEffect() async throws {
        for placement: BannerPlacement in [.adaptive, .fixed] {
            host(BannerView(banner: MotionBanner(position: .topTrailing, duration: .infinity, animation: nil), placement: placement))
            try? await Task.sleep(for: .milliseconds(100))
            let frame = try XCTUnwrap(capture("placement-\(placement)"))
            XCTAssertEqual(frame.maxX, 340, accuracy: 2)
            XCTAssertEqual(frame.minY, 20, accuracy: 2)
        }
    }
    #endif

    func testIPTVRepresentativeTransitions() async throws {
        for scenario in 0..<3 {
            #if os(macOS)
            let widths: [CGFloat] = [240, 800]
            #else
            let widths: [CGFloat] = [240, 360]
            #endif
            for width in widths {
                // Dilate the caller's curve so compositor startup and snapshot
                // overhead cannot consume most of a 0.3-second transition.
                let start = await beginMotion(BannerView(banner: IPTVPresentationFixture(scenario: scenario), duration: 4), width: width, name: "iptv-\(scenario)-\(width)")
                var frames: [CGRect?] = []
                for (name, time) in [("early",0.20),("mid",0.80),("rest",3.20),("exit-start",4.08),("exit-mid",4.80),("removed",6.50)] {
                    try? await Task.sleep(until: start.advanced(by: .seconds(time)), clock: .continuous)
                    frames.append(try capture("iptv-\(scenario)-\(width)-\(name)", blue: scenario != 1))
                }
                let rest = try XCTUnwrap(frames[2])
                print("APPFIXTURE scenario=\(scenario) host=\(width)x300 position=\(scenario == 0 ? "topTrailing" : "bottomTrailing") placement=default edge=\(scenario == 2 ? "bottom" : "trailing") stackOffset=0 proposal=\(IPTVMeasurement.proposal) measured=\(IPTVMeasurement.size) visibleRest=\(rest)")
                XCTAssertLessThanOrEqual(rest.maxX, width)
                XCTAssertNotNil(frames[1])
                if let mid = frames[1] {
                    if scenario == 2 { XCTAssertGreaterThan(mid.midY, rest.midY) }
                    else { XCTAssertGreaterThan(mid.midX, rest.midX) }
                }
                XCTAssertNil(frames[5])
            }
        }
    }

    func testMixedSingletonDoesNotReserveStackSpace() async throws {
        let manager = BannerManager<MotionBanner>(stackGap: 7)
        manager.enqueue(MotionBanner(position: .bottomTrailing, duration: .infinity, animation: nil))
        manager.enqueue(MotionBanner(position: .bottomTrailing, key: 1, height: 70, stacks: true, duration: .infinity, animation: nil))
        host(Color.clear.bannerOverlay(manager))
        try? await Task.sleep(for: .milliseconds(100))
        let blue = try XCTUnwrap(capture("mixed-singleton-stack", blue: true))
        XCTAssertEqual(blue.maxY, 280, accuracy: 2, "singletons are excluded from the pile, as in the reference queue")
        manager.clear()
    }

    func testStackSpacingOrderingAndCrossAnchorZOrder() async throws {
        let manager = BannerManager<MotionBanner>(stackGap: 7)
        manager.enqueue(MotionBanner(position: .bottomTrailing, height: 40, stacks: true, duration: .infinity, animation: nil))
        manager.enqueue(MotionBanner(position: .bottomTrailing, key: 1, height: 70, stacks: true, duration: .infinity, animation: nil))
        host(Color.clear.bannerOverlay(manager))
        try? await Task.sleep(for: .milliseconds(100))
        let red = try XCTUnwrap(capture("stack-oldest"))
        let blue = try XCTUnwrap(capture("stack-newest", blue: true))
        XCTAssertGreaterThan(red.midY, blue.midY)
        XCTAssertEqual(red.minY-blue.maxY, 7, accuracy: 2)
        manager.clear()
        // Force two different anchors to overlap. Newest enqueue must draw last,
        // independent of which anchor it uses.
        manager.enqueue(MotionBanner(position: .bottomTrailing, height: 260, stacks: true, duration: .infinity, animation: nil))
        manager.enqueue(MotionBanner(position: .topTrailing, key: 1, height: 100, stacks: true, duration: .infinity, animation: nil))
        try? await Task.sleep(for: .milliseconds(100))
        let last = try XCTUnwrap(capture("cross-anchor-newest", blue: true))
        XCTAssertGreaterThan(last.height, 90, "global enqueue z-order must not become anchor order")
        manager.clear()
    }
}

/// Diagnostic values only; no SwiftUI state observes these measurements.
private enum IPTVMeasurement {
    static var proposal = ProposedViewSize.unspecified
    static var size = CGSize.zero
}
private struct IPTVProposalProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(proposal) ?? .zero
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        IPTVMeasurement.proposal = proposal
        IPTVMeasurement.size = bounds.size
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

/// Same position, edge, curve, duration and content structure as the app's
/// BannerType/M3uItemTitleView/PlayerErrorView/MetadataView, using synthetic text.
/// The test passes the same short duration override to each revision.
private struct IPTVPresentationFixture: BannerPresentable {
    var scenario: Int
    var bannerProperties: BannerProperties {
        BannerProperties(frame: .zero, duration: scenario == 0 ? 4 : scenario == 1 ? 7.6 : 3,
                         position: scenario == 0 ? .topTrailing : .bottomTrailing,
                         cornerRadius: 25, fillColor: scenario == 1 ? .red : .blue,
                         opacity: scenario == 2 ? 0.7 : 0.9,
                         showAnimation: (scenario == 1 ? Animation.spring(response: 0.5, dampingFraction: 0.6) : .easeInOut(duration: 0.3)).speed(0.25),
                         showFrom: scenario == 2 ? .bottom : .trailing, textColor: .white,
                         renderScale: 1)
    }
    func makeContent() -> some View {
        IPTVProposalProbe { Group {
            if scenario == 2 {
                VStack { Text("Metadata title").lineLimit(2); Text("Metadata details").lineLimit(2) }
            } else {
                Text(scenario == 0 ? "Channel title" : "Player error message")
                    .lineLimit(scenario == 0 ? 3 : 4).truncationMode(.tail)
            }
        }
        .multilineTextAlignment(.center)
        .font(.system(size: scenario == 0 ? 34 : 26))
        .padding(20)
        .foregroundStyle(.white)
        .background(bannerProperties.fillColor.opacity(bannerProperties.opacity),
                    in: RoundedRectangle(cornerRadius: 25))
        }
        .onAppear { MotionMountClock.mounted = .now }
    }
}

@MainActor
private final class MotionVisibility: ObservableObject {
    @Published var visible = false
}
private struct MotionMount<Content: View>: View {
    @ObservedObject var visibility: MotionVisibility
    var content: Content
    var body: some View { if visibility.visible { content } }
}

@MainActor
private enum MotionMountClock {
    static var mounted: ContinuousClock.Instant?
}
