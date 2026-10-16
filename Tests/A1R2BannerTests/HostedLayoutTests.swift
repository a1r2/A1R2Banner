import XCTest
import SwiftUI
@testable import A1R2Banner
#if os(macOS)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

#if os(macOS)
private typealias ProbeView = NSView
#else
private typealias ProbeView = UIView
#endif

@MainActor
private enum NativeFrames {
    static var views: [String: ProbeView] = [:]
}

#if os(macOS)
private final class MeasurementNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct NativeProbe: NSViewRepresentable {
    let name: String
    func makeNSView(context: Context) -> NSView {
        let view = MeasurementNSView()
        NativeFrames.views[name] = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) {}
}
#else
private struct NativeProbe: UIViewRepresentable {
    let name: String
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        NativeFrames.views[name] = view
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {}
}
#endif

private extension View {
    func record(_ name: String) -> some View { background(NativeProbe(name: name)) }
}

private struct ProbeBanner: BannerPresentable {
    var kind: Int
    var position: BannerPosition = .topTrailing
    var stacks = false
    var maximumWidth: CGFloat = 560
    var renderScale: CGFloat? = nil
    var bannerProperties: BannerProperties {
        BannerProperties(frame: CGSize(width: 0, height: 10), duration: .infinity,
                         position: position, showAnimation: nil, renderScale: renderScale, stacks: stacks, maximumWidth: maximumWidth)
    }
    @ViewBuilder func makeContent() -> some View {
        Group {
            switch kind {
            case 0: Text("Short")
            case 1: Text(String(repeating: "Long wrapping content with spaces. ", count: 12))
            case 2: Text("First line\nSecond line\nThird line")
            case 3: Text(String(repeating: "W", count: 250))
            case 4: HStack { Image(systemName: "info.circle"); Text(String(repeating: "Label ", count: 20)) }
            case 5: VStack { Text("Title"); Text(String(repeating: "Details ", count: 30)) }
            case 7: Text("Tall").frame(minHeight: 100)
            default: Rectangle().fill(.red).frame(width: 900, height: 80)
            }
        }
        .padding(8)
        .background(.blue)
        .record("content\(kind)")
    }
}

/// Real SwiftUI hosts, not a reimplementation of its measurement algorithm.
@MainActor
final class HostedLayoutTests: XCTestCase {
    private var frames: [String: CGRect] = [:]
    #if os(macOS)
    private var window: NSWindow?
    #elseif os(iOS) || os(tvOS)
    private var window: UIWindow?
    #endif

    private func host<V: View>(_ view: V, size: CGSize) async {
        frames = [:]
        NativeFrames.views = [:]
        #if os(macOS)
        window?.orderOut(nil)
        #else
        window?.isHidden = true
        #endif
        let root = view.transaction { $0.disablesAnimations = true }.frame(width: size.width, height: size.height)
            .record("host")
        #if os(macOS)
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        self.window = window
        hosting.frame = CGRect(origin: .zero, size: size)
        window.orderFrontRegardless()
        window.display()
        hosting.layoutSubtreeIfNeeded()
        #elseif os(iOS) || os(tvOS)
        let controller = UIHostingController(rootView: root)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller
        controller.view.backgroundColor = .black
        window.makeKeyAndVisible()
        self.window = window
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #endif
        try? await Task.sleep(for: .milliseconds(250))
        #if os(macOS)
        hosting.layoutSubtreeIfNeeded()
        #elseif os(iOS) || os(tvOS)
        controller.view.layoutIfNeeded()
        #endif
        #if os(macOS)
        frames = NativeFrames.views.mapValues { $0.convert($0.bounds, to: hosting) }
        #else
        frames = NativeFrames.views.mapValues { $0.convert($0.bounds, to: controller.view) }
        #endif
    }

    private func refreshFrames() {
        #if os(macOS)
        guard let root = window?.contentView else { return }
        root.layoutSubtreeIfNeeded()
        frames = NativeFrames.views.mapValues { $0.convert($0.bounds, to: root) }
        #else
        guard let root = window?.rootViewController?.view else { return }
        root.layoutIfNeeded()
        frames = NativeFrames.views.mapValues { $0.convert($0.bounds, to: root) }
        #endif
    }

    private func snapshot(_ name: String) throws -> CGImage {
        #if os(macOS)
        let root = try XCTUnwrap(window?.contentView)
        let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
        root.cacheDisplay(in: root.bounds, to: bitmap)
        let image = try XCTUnwrap(bitmap.cgImage)
        let attachment = XCTAttachment(data: try XCTUnwrap(bitmap.representation(using: .png, properties: [:])), uniformTypeIdentifier: "public.png")
        #else
        let root = try XCTUnwrap(window?.rootViewController?.view)
        let region = try XCTUnwrap(frames["host"])
        let rendered = UIGraphicsImageRenderer(size: region.size).image { context in
            context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            root.drawHierarchy(in: root.bounds, afterScreenUpdates: true)
        }
        let image = try XCTUnwrap(rendered.cgImage)
        let attachment = XCTAttachment(image: rendered)
        #endif
        #if os(macOS)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("A1R2BannerLayoutTests")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])?.write(to: directory.appendingPathComponent(name + ".png"))
        print("SNAPSHOT \(directory.appendingPathComponent(name + ".png").path)")
        #endif
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func contained(_ child: CGRect, in parent: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(child.minX, parent.minX - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(child.maxX, parent.maxX + 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(child.minY, parent.minY - 1, file: file, line: line)
        XCTAssertLessThanOrEqual(child.maxY, parent.maxY + 1, file: file, line: line)
    }

    func testPublicBannerCustomContentAcrossRegions() async throws {
        for width: CGFloat in [44, 120, 240, 360, 800, 1920] {
            for kind in 0...5 {
                await host(BannerView(banner: ProbeBanner(kind: kind))
                    , size: CGSize(width: width, height: 320))
                let content = try XCTUnwrap(frames["content\(kind)"])
                let region = try XCTUnwrap(frames["host"])
                // A very narrow HStack can refuse the proposal because its icon
                // and glyph have minimum sizes; the SDK clips its bounded surface.
                if width >= 240 || kind != 4 { contained(content, in: region) }
                XCTAssertLessThanOrEqual(content.width, 560.5)
                print("LAYOUT custom=\(kind) host=\(width)x320 content=\(content)")
            }
        }
    }

    func testGlassTextWrappingDynamicTypeAndRTL() async throws {
        for width: CGFloat in [120, 240, 360, 800] {
            for rtl in [false, true] {
                await host(GlassBannerContent(banner: GlassBanner(
                    title: String(repeating: "Long title ", count: 8),
                    subtitle: "Subtitle wraps normally", systemImage: "star.fill"))
                    .record("glass")

                    .environment(\.dynamicTypeSize, .accessibility3)
                    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight),
                    size: CGSize(width: width, height: 600))
                let glass = try XCTUnwrap(frames["glass"])
                contained(glass, in: try XCTUnwrap(frames["host"]))
                print("LAYOUT glass host=\(width)x600 rtl=\(rtl) bounds=\(glass)")
            }
        }
    }

    func testBoundedSurfaceAndExplicitScale() async throws {
        for scale: CGFloat in [0.005, 0.4, 0.5, 1, 2, 1000] {
            for width: CGFloat in [0, 1, 12, 120, 360, 2000] {
                await host(BannerContentLayout(maximumWidth: 560, scale: scale) {
                    Rectangle().fill(.red).frame(width: 900, height: 100)
                        .scaleEffect(scale, anchor: .topLeading).record("raw")
                }.clipped().contentShape(Rectangle()).record("surface"),
                     size: CGSize(width: width, height: 40))
                let surface = try XCTUnwrap(frames["surface"])
                XCTAssertLessThanOrEqual(surface.width, min(width, 560) + 0.5)
                XCTAssertLessThanOrEqual(surface.height, 40.5)
                print("LAYOUT fixed host=\(width)x40 scale=\(scale) surface=\(surface)")
            }
        }
    }

    func testLegacyTransformMeasurementMismatchAndReplacement() async throws {
        await host(Color.red.frame(width: 800, height: 100).record("paint")
            .scaleEffect(0.4, anchor: .topLeading).record("layout"),
             size: CGSize(width: 360, height: 120))
        let oldLayout = try XCTUnwrap(frames["layout"])
        let oldPaint = try XCTUnwrap(frames["paint"])
        XCTAssertEqual(oldLayout.width, 800, accuracy: 1)
        XCTAssertEqual(oldPaint.width, 320, accuracy: 1)
        await host(BannerContentLayout(maximumWidth: 560, scale: 0.4) {
            Color.red.frame(width: 800, height: 100).record("paint")
                .scaleEffect(0.4, anchor: .topLeading)
        }.clipped().contentShape(Rectangle()).record("layout"),
             size: CGSize(width: 360, height: 120))
        let newLayout = try XCTUnwrap(frames["layout"])
        let newPaint = try XCTUnwrap(frames["paint"])
        XCTAssertEqual(newLayout.width, 320, accuracy: 1)
        XCTAssertEqual(newPaint.width, newLayout.width, accuracy: 1)
        print("SCALE oldLayout=\(oldLayout.width) oldPaint=\(oldPaint.width) newLayout=\(newLayout.width) newPaint=\(newPaint.width)")
    }

    func testGlassForegroundRenderingAndOverride() async throws {
        #if !os(tvOS)
        throw XCTSkip("View-hierarchy capture does not reliably capture composited Liquid Glass on this platform. Use Starter --layout-review and a system screenshot; foreground data contract is tested separately.")
        #else
        for scheme: ColorScheme in [.light, .dark] {
            for (name, color) in [("white", Color.white), ("orange", Color.orange)] {
                await host((scheme == .light ? Color.white : Color.black).overlay {
                    GlassBannerContent(banner: GlassBanner(title: "Foreground", subtitle: "Matching symbol", systemImage: "star.fill", tint: .black, textColor: color)).record("glass")
                }.preferredColorScheme(scheme), size: CGSize(width: 360, height: 160))
                try? await Task.sleep(for: .milliseconds(850))
                refreshFrames()
                let image = try snapshot("glass-foreground-\(scheme)-\(name)")
                let glass = try XCTUnwrap(frames["glass"])
                let region = try XCTUnwrap(frames["host"])
                // Sample the capsule's interior, excluding the host and bright rim.
                let core = glass.insetBy(dx: glass.width / 4, dy: glass.height / 4)
                let scale = CGFloat(image.width) / region.width
                let crop = CGRect(x: (core.minX - region.minX) * scale,
                                  y: (core.minY - region.minY) * scale,
                                  width: core.width * scale, height: core.height * scale).integral
                let sampled = try XCTUnwrap(image.cropping(to: crop))
                var bytes = [UInt8](repeating: 0, count: sampled.width * sampled.height * 4)
                bytes.withUnsafeMutableBytes { buffer in
                    let context = CGContext(data: buffer.baseAddress, width: sampled.width, height: sampled.height,
                        bitsPerComponent: 8, bytesPerRow: sampled.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    context.draw(sampled, in: CGRect(x: 0, y: 0, width: sampled.width, height: sampled.height))
                }
                var matchingPixels = 0
                var backgroundBins = [Int](repeating: 0, count: 16)
                for i in stride(from: 0, to: bytes.count, by: 4) {
                    if name == "white" {
                        if bytes[i] > 220 && bytes[i+1] > 220 && bytes[i+2] > 220 { matchingPixels += 1 }
                        backgroundBins[Int(bytes[i]) / 16] += 1
                    // Semantic orange resolves darker in Light Mode. Check hue,
                    // not a fixed brightness that only matches Dark Mode.
                    } else if bytes[i] > 100 && bytes[i+1] > 30 && bytes[i+1] < 210 && bytes[i+2] < 100
                                && Int(bytes[i]) * 10 > Int(bytes[i+1]) * 13
                                && Int(bytes[i+1]) * 10 > Int(bytes[i+2]) * 13 {
                        matchingPixels += 1
                    }
                }
                XCTAssertGreaterThan(matchingPixels, 20, "foreground renders in its semantic color inside the capsule")
                if name == "white" {
                    let background = try XCTUnwrap(backgroundBins.indices.max(by: { backgroundBins[$0] < backgroundBins[$1] }))
                    // Conservative upper edge of the predominant background bin.
                    let channel = Double(min(255, (background + 1) * 16)) / 255
                    let luminance = channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
                    XCTAssertGreaterThanOrEqual(1.05 / (luminance + 0.05), 4.5,
                        "default white must contrast with the capsule backing on either host scheme")
                    print("CONTRAST \(scheme) conservativeWhiteRatio=\(1.05 / (luminance + 0.05))")
                }
                print("FOREGROUND \(scheme) \(name) matchingPixels=\(matchingPixels)")
            }
        }
        #endif
    }

    func testPublicDefaultAndExplicitArtworkScales() async throws {
        for scale: CGFloat? in [nil, 1, 0.005, 1000] {
            await host(BannerView(banner: ProbeBanner(kind: 6, renderScale: scale)),
                       size: CGSize(width: 360, height: 200))
            let paint = try XCTUnwrap(frames["content6"])
            XCTAssertEqual(paint.width, 916 * (scale ?? 1), accuracy: 1)
            XCTAssertTrue(paint.width.isFinite && paint.height.isFinite)
        }
    }

    func testMaximumWidthOverridesAndIntrinsicShortContent() async throws {
        for maximum: CGFloat in [240, 560, 900] {
            await host(BannerView(banner: ProbeBanner(kind: 1, maximumWidth: maximum)),
                       size: CGSize(width: 1920, height: 1000))
            let long = try XCTUnwrap(frames["content1"])
            XCTAssertLessThanOrEqual(long.width, maximum + 1)
            if maximum == 900 { XCTAssertGreaterThan(long.width, 560) }
            await host(BannerView(banner: ProbeBanner(kind: 0, maximumWidth: maximum)),
                       size: CGSize(width: 1920, height: 1000))
            XCTAssertLessThan(try XCTUnwrap(frames["content0"]).width, 240)
        }
        await host(BannerView(banner: ProbeBanner(kind: 1, maximumWidth: 900)),
                   size: CGSize(width: 120, height: 1000))
        contained(try XCTUnwrap(frames["content1"]), in: try XCTUnwrap(frames["host"]))
    }

    #if os(iOS)
    func testDynamicTypeIncreasesContentHeight() async throws {
        await host(BannerView(banner: ProbeBanner(kind: 1)).environment(\.dynamicTypeSize, .large),
                   size: CGSize(width: 360, height: 2000))
        let ordinary = try XCTUnwrap(frames["content1"]).height
        await host(BannerView(banner: ProbeBanner(kind: 1)).environment(\.dynamicTypeSize, .accessibility3),
                   size: CGSize(width: 360, height: 2000))
        XCTAssertGreaterThan(try XCTUnwrap(frames["content1"]).height, ordinary)
    }
    #endif

    func testStackResizesRemovesAndReplacesWithoutStaleGeometry() async throws {
        let manager = BannerManager<ProbeBanner>(stackGap: 7)
        let geometry = ChangingRegion()
        for kind in [0, 2, 7] { manager.enqueue(ProbeBanner(kind: kind, position: .bottomTrailing, stacks: true)) }
        await host(ResizingStackProbe(geometry: geometry, manager: manager)
            .environment(\.dynamicTypeSize, .accessibility3), size: CGSize(width: 1400, height: 1200))
        for width: CGFloat in [240, 800, 360, 1200, 240] {
            geometry.width = width
            try? await Task.sleep(for: .milliseconds(80))
            refreshFrames()
            let region = try XCTUnwrap(frames["region"])
            let surfaces = try [0, 2, 7].map { try XCTUnwrap(frames["content\($0)"]) }
            for surface in surfaces { contained(surface, in: region) }
            XCTAssertEqual(surfaces[0].minY - surfaces[1].maxY, 7, accuracy: 1)
            XCTAssertEqual(surfaces[1].minY - surfaces[2].maxY, 7, accuracy: 1)
        }
        let middle = try XCTUnwrap(manager.items.first { $0.banner.kind == 2 })
        manager.dismiss(id: middle.id)
        try? await Task.sleep(for: .milliseconds(80))
        refreshFrames()
        XCTAssertEqual(try XCTUnwrap(frames["content0"]).minY - XCTUnwrap(frames["content7"]).maxY, 7, accuracy: 1)
        XCTAssertNil(NativeFrames.views["content2"]?.window)
        for _ in 0..<3 {
            manager.enqueue(ProbeBanner(kind: 2, position: .bottomTrailing, stacks: true), duration: 0.05)
            try? await Task.sleep(for: .milliseconds(20))
            manager.dismiss(id: try XCTUnwrap(manager.items.last).id)
        }
        manager.enqueue(ProbeBanner(kind: 2, position: .bottomTrailing, stacks: true))
        try? await Task.sleep(for: .milliseconds(550))
        refreshFrames()
        XCTAssertEqual(manager.items.count, 3)
        XCTAssertNotNil(NativeFrames.views["content2"]?.window, "cancelled older timers cannot remove the replacement")
        manager.clear()
        try? await Task.sleep(for: .milliseconds(80))
        for kind in [0, 2, 7] { XCTAssertNil(NativeFrames.views["content\(kind)"]?.window) }
        manager.enqueue(ProbeBanner(kind: 0, position: .topCenter, stacks: true))
        try? await Task.sleep(for: .milliseconds(80))
        manager.enqueue(ProbeBanner(kind: 7, position: .topCenter, stacks: true))
        try? await Task.sleep(for: .milliseconds(80))
        refreshFrames()
        XCTAssertEqual(manager.items.count, 1, "top banners replace rather than pile")
        XCTAssertNil(NativeFrames.views["content0"]?.window)
        let top = try XCTUnwrap(frames["content7"])
        let region = try XCTUnwrap(frames["region"])
        contained(top, in: region)
        XCTAssertEqual(top.minY - region.minY, 20, accuracy: 1)
        manager.clear()
    }

    func testUnspecifiedHeightUsesWrappingIntrinsicHeight() async throws {
        await host(BannerView(banner: ProbeBanner(kind: 1))
            .fixedSize(horizontal: false, vertical: true).record("intrinsic"),
             size: CGSize(width: 120, height: 2000))
        let content = try XCTUnwrap(frames["content1"])
        let intrinsic = try XCTUnwrap(frames["intrinsic"])
        XCTAssertGreaterThan(content.height, 100)
        contained(content, in: intrinsic)
        XCTAssertEqual(intrinsic.height, content.height + 40, accuracy: 2)
    }

    #if os(tvOS)
    func testCustomButtonCanReceiveFocus() async throws {
        FocusObservation.focused = false
        await host(BannerView(banner: FocusBanner()), size: CGSize(width: 560, height: 300))
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(FocusObservation.focused, "the SDK must not disable or trap custom-content focus")
    }
    #endif

    func testNarrowAndShortPresentationSurface() async throws {
        for width: CGFloat in [0, 1, 12, 44, 120] {
            for kind in 0...6 {
                await host(BannerRegionLayout(position: .topTrailing) {
                    BannerPresentation(banner: ProbeBanner(kind: kind)).record("surface")
                }.clipped(), size: CGSize(width: width, height: 40))
                contained(try XCTUnwrap(frames["surface"]), in: try XCTUnwrap(frames["host"]))
            }
        }
    }

    #if os(macOS)
    func testPublicOverlayPassesBackgroundClicksAndBoundsAnimatedHits() async throws {
        var backgroundHits = 0
        TapObservation.hits = 0
        let manager = BannerManager<TapBanner>()
        manager.enqueue(TapBanner())
        await host(Color.green.onTapGesture { backgroundHits += 1 }
            .overlay {
                Color.clear.frame(width: 240, height: 100).bannerOverlay(manager).record("region")
            }, size: CGSize(width: 360, height: 300))
        let window = try XCTUnwrap(window)
        func click(_ point: CGPoint) {
            for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type,
                    location: CGPoint(x: point.x, y: 300 - point.y), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
                window.sendEvent(event)
            }
        }
        let region = try XCTUnwrap(frames["region"])
        click(CGPoint(x: region.midX, y: region.minY - 10))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(TapObservation.hits, 0, "a transitioning banner cannot receive a click outside its host")
        XCTAssertEqual(backgroundHits, 1)
        try? await Task.sleep(for: .milliseconds(1000))
        refreshFrames()
        let content = try XCTUnwrap(frames["tappable"])
        click(CGPoint(x: content.midX, y: content.midY))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(TapObservation.hits, 1)
        click(CGPoint(x: 10, y: 10))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(backgroundHits, 2, "unused overlay space passes clicks to the host")
        manager.clear()
        try? await Task.sleep(for: .milliseconds(80))
        click(CGPoint(x: content.midX, y: content.midY))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(TapObservation.hits, 1)
        XCTAssertEqual(backgroundHits, 3, "removing the last banner releases its interaction region")
    }

    func testStackInteractionRegionsTrackRemoval() async throws {
        var backgroundHits = 0
        TapObservation.hits = 0
        let manager = BannerManager<TapBanner>()
        manager.enqueue(TapBanner(key: 1, height: 40, position: .bottomTrailing, stacks: true))
        manager.enqueue(TapBanner(key: 2, height: 100, position: .bottomTrailing, stacks: true))
        await host(Color.green.onTapGesture { backgroundHits += 1 }.bannerOverlay(manager),
                   size: CGSize(width: 360, height: 400))
        try? await Task.sleep(for: .milliseconds(1100))
        refreshFrames()
        let window = try XCTUnwrap(window)
        func click(_ point: CGPoint) {
            for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
                window.sendEvent(NSEvent.mouseEvent(with: type,
                    location: CGPoint(x: point.x, y: 400 - point.y), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!)
            }
        }
        let lower = try XCTUnwrap(frames["tappable1"])
        let upper = try XCTUnwrap(frames["tappable2"])
        click(CGPoint(x: lower.midX, y: lower.midY))
        click(CGPoint(x: upper.midX, y: upper.midY))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(TapObservation.hits, 2)
        click(CGPoint(x: lower.midX, y: (lower.minY + upper.maxY) / 2))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(backgroundHits, 1, "the space between measured banners is not interactive")
        manager.dismiss(id: try XCTUnwrap(manager.items.first).id)
        try? await Task.sleep(for: .milliseconds(1100))
        refreshFrames()
        XCTAssertNil(NativeFrames.views["tappable1"]?.window)
        let remaining = try XCTUnwrap(frames["tappable2"])
        XCTAssertEqual(remaining.maxY, try XCTUnwrap(frames["host"]).maxY - 20, accuracy: 1)
        click(CGPoint(x: upper.midX, y: upper.midY))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(backgroundHits, 2, "the old stack position no longer intercepts interaction")
        manager.clear()
        try? await Task.sleep(for: .milliseconds(80))
        click(CGPoint(x: remaining.midX, y: remaining.midY))
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(TapObservation.hits, 2)
        XCTAssertEqual(backgroundHits, 3)
    }

    func testClippedContentDoesNotReceiveClicksOutsideSurface() async throws {
        var hits = 0
        await host(BannerContentLayout(maximumWidth: 120) {
            Color.red.frame(width: 900, height: 80).onTapGesture { hits += 1 }
        }.clipped().contentShape(Rectangle()).record("surface"), size: CGSize(width: 240, height: 80))
        let window = try XCTUnwrap(window)
        func click(x: CGFloat) {
            for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: CGPoint(x: x, y: 40),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 1,
                    clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
                window.sendEvent(event)
            }
        }
        click(x: 120)
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(hits, 1, "visible content receives a click")
        click(x: 220)
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(hits, 1, "clipped overflow must not receive a click")
    }
    #endif

    func testAnchorDirectionsIncludingRTL() async throws {
        for rtl in [false, true] {
            for position: BannerPosition in [.topLeading, .topTrailing, .topCenter, .bottomLeading, .bottomTrailing, .bottomCenter] {
                await host(BannerView(banner: ProbeBanner(kind: 0, position: position))
                    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight),
                     size: CGSize(width: 360, height: 240))
                let content = try XCTUnwrap(frames["content0"])
                let region = try XCTUnwrap(frames["host"])
                contained(content, in: region)
                switch position {
                case .topCenter, .bottomCenter: XCTAssertEqual(content.midX, region.midX, accuracy: 1)
                case .topLeading, .bottomLeading:
                    XCTAssertEqual(rtl ? region.maxX - content.maxX : content.minX - region.minX, 20, accuracy: 1)
                default:
                    XCTAssertEqual(rtl ? content.minX - region.minX : region.maxX - content.maxX, 20, accuracy: 1)
                }
            }
        }
    }

    func testContinuousResizingRelayoutsExistingBanner() async throws {
        let geometry = ChangingRegion()
        await host(ResizingProbe(geometry: geometry), size: CGSize(width: 1400, height: 500))
        for width: CGFloat in [1200, 360, 120, 44, 800, 240, 1200] {
            geometry.width = width
            try? await Task.sleep(for: .milliseconds(60))
            refreshFrames()
            let content = try XCTUnwrap(frames["content1"])
            let region = try XCTUnwrap(frames["region"])
            contained(content, in: region)
            XCTAssertLessThanOrEqual(content.width, 560.5)
            print("RESIZE host=\(width) content=\(content)")
        }
    }

    func testRasterizedBackgroundIsClippedToMeasuredSurface() async throws {
        await host(BannerContentLayout(maximumWidth: 120) {
            Rectangle().fill(.red).frame(width: 900, height: 100)
        }.clipped().contentShape(Rectangle()).record("surface").background(.green),
             size: CGSize(width: 240, height: 80))
        let surface = try XCTUnwrap(frames["surface"])
        let image = try snapshot("fixed-content-clipping-240x80")
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        var redColumns = Set<Int>()
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                if bytes[i] > 180 && bytes[i + 1] < 80 && bytes[i + 2] < 80 { redColumns.insert(x) }
            }
        }
        XCTAssertFalse(redColumns.isEmpty)
        let scale = CGFloat(width) / 240
        XCTAssertLessThanOrEqual(CGFloat(redColumns.count) / scale, surface.width + 1)
        print("RASTER host=240x80 surface=\(surface) visibleRedWidth=\(CGFloat(redColumns.count) / scale)")
    }

    func testMeasuredStackUsesContentHeightInsteadOfFrameHint() async throws {
        let manager = BannerManager<ProbeBanner>(stackGap: 7)
        manager.enqueue(ProbeBanner(kind: 0, position: .bottomTrailing, stacks: true))
        manager.enqueue(ProbeBanner(kind: 2, position: .bottomTrailing, stacks: true))
        await host(Color.clear.bannerOverlay(manager),
                   size: CGSize(width: 360, height: 600))
        let first = try XCTUnwrap(frames["content0"])
        let second = try XCTUnwrap(frames["content2"])
        XCTAssertGreaterThan(first.height, 10)
        XCTAssertEqual(first.minY - second.maxY, 7, accuracy: 1)
        contained(first, in: try XCTUnwrap(frames["host"]))
        contained(second, in: try XCTUnwrap(frames["host"]))
        manager.clear()
    }
}

@MainActor
private final class ChangingRegion: ObservableObject {
    @Published var width: CGFloat = 360
}

private struct ResizingProbe: View {
    @ObservedObject var geometry: ChangingRegion
    var body: some View {
        BannerView(banner: ProbeBanner(kind: 1))
            .frame(width: geometry.width, height: 400)
            .record("region")
    }
}

private struct ResizingStackProbe: View {
    @ObservedObject var geometry: ChangingRegion
    @ObservedObject var manager: BannerManager<ProbeBanner>
    var body: some View {
        Color.clear.bannerOverlay(manager)
            .frame(width: geometry.width, height: 1000).record("region")
    }
}

#if os(tvOS)
@MainActor
private enum FocusObservation { static var focused = false }

private struct FocusBanner: BannerPresentable {
    var bannerProperties: BannerProperties {
        BannerProperties(frame: .zero, duration: .infinity, position: .topCenter, showAnimation: nil)
    }
    func makeContent() -> some View { FocusProbeContent() }
}

private struct FocusProbeContent: View {
    @FocusState private var focused: Bool
    var body: some View {
        Button("Banner action") {}
            .focused($focused)
            .defaultFocus($focused, true)
            .onChange(of: focused) { _, value in FocusObservation.focused = value }
    }
}
#endif

#if os(macOS)
@MainActor
private enum TapObservation { static var hits = 0 }

private struct TapBanner: BannerPresentable {
    var key = 0
    var height: CGFloat = 80
    var position: BannerPosition = .topCenter
    var stacks = false
    var bannerProperties: BannerProperties {
        BannerProperties(frame: .zero, duration: .infinity, position: position,
                         showAnimation: .linear(duration: 1), stacks: stacks)
    }
    func makeContent() -> some View {
        Color.red.frame(height: height).record(key == 0 ? "tappable" : "tappable\(key)")
            .onTapGesture { TapObservation.hits += 1 }
    }
}
#endif
