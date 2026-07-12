# BannerKit SDK Extraction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the reusable banner queue/stacking/rendering engine out of `iptvFaves/Views/Banner/` into a standalone Swift package (`BannerKit`) that any app can adopt, leaving only app-specific content and styling behind a protocol.

**Architecture:** Invert the dependency with a `BannerPresentable` protocol (chosen seam). The SDK owns the engine (`BannerManager`), the styling model (`BannerProperties`, `BannerPosition`), the queue item, the rendering views/modifiers, and a container modifier. The app keeps its `BannerType` enum, its content views (`PlayerErrorView`, `M3uItemDetailsView`, …), its durations, and its localized strings — and makes `BannerType` conform to `BannerPresentable`. Call sites (`BannerManager.shared.addBannerToQueue(bannerType:duration:)`) stay unchanged.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Package Manager (local package), Xcode project integration via the `xcodeproj` ruby gem (v1.27.0, already used in this repo). Targets tvOS 18 / iOS 18 (match the app).

**Precondition:** Do NOT start until after tomorrow's QA of the current app. Work on a dedicated branch off `Development` (e.g. `bannerkit-extraction`). The app suite must be green (currently 252) before and after.

---

## Observed coupling (why each seam exists)

| App-specific today | Where | How the SDK decouples it |
|---|---|---|
| `BannerType` enum (8 cases) | `BannerType.swift` | Stays in app; conforms to `BannerPresentable` |
| Content views (`M3uItemTitleView`, `Add2favesFailedView`, `PlayerErrorView`, `M3uItemDetailsView`, `MetadataView`) | referenced in `BannerView.bannerContent()` | Stay in app; returned from `makeContent()` |
| Implicit **position** (corner grouping) | `BannerView.bannerAnchorPoint`, `BannerModifier.applyBannerModifier` switches | Promoted to explicit `BannerPosition` on `BannerProperties` |
| `favoritesEditHint` padding special-case | `BannerModifier.bannerTopPadding`/`bannerTrailingPadding` | Optional `iOSInsetOverride` on `BannerProperties` |
| `DDLogger` | `BannerManager`, `BannerView` | Injectable `log:` closure, silent default |
| `FontSizes.banners`, `BannerDuration.*`, `BannerMessage` (NSLocalizedString) | `BannerType.properties`, call sites | Stay in app (passed into `BannerProperties`) |
| `Array[safe:]` subscript | `BannerManager` offset code | Add a private copy inside the SDK |
| `playerErrorCount` | `BannerManager` | Effectively unused externally — drop it in the SDK |

---

## File Structure

**New package `BannerKit/` (repo root):**
- `BannerKit/Package.swift` — package manifest, one library product `BannerKit`.
- `BannerKit/Sources/BannerKit/BannerPosition.swift` — `public enum BannerPosition`.
- `BannerKit/Sources/BannerKit/BannerProperties.swift` — moved+extended styling model (adds `position`, `iOSInsetOverride`).
- `BannerKit/Sources/BannerKit/BannerPresentable.swift` — the protocol seam.
- `BannerKit/Sources/BannerKit/BannerItem.swift` — generic queue item (was `BannerToQueue`).
- `BannerKit/Sources/BannerKit/BannerManager.swift` — generic engine (queue, dedup, offsets, lifecycle, injectable logger).
- `BannerKit/Sources/BannerKit/BannerView.swift` — renders one banner via `makeContent()` + position.
- `BannerKit/Sources/BannerKit/BannerModifier.swift` — position-driven padding/transition (no app types).
- `BannerKit/Sources/BannerKit/BannerOverlayView.swift` — the ForEach stack over the manager's queue.
- `BannerKit/Sources/BannerKit/View+BannerOverlay.swift` — `.bannerOverlay(_:)` container modifier the host attaches once.
- `BannerKit/Sources/BannerKit/Internal/Array+safe.swift` — private `subscript(safe:)`.
- `BannerKit/Tests/BannerKitTests/BannerManagerTests.swift` — engine unit tests (queue/dedup/offset/lifecycle) using a stub `BannerPresentable`.

**App changes (`iptvFaves/`):**
- Keep + edit: `Views/Banner/BannerType.swift` — conform to `BannerPresentable`; add `position`/overrides to each case's `BannerProperties`; add `makeContent()`.
- Keep as-is: the content views (`M3uItemTitleView`, `Add2favesFailedView`, `PlayerErrorView`, `M3uItemDetailsView`, `MetadataView`) — wherever they currently live.
- Keep + edit: `Views/Banner/BannerDuration.swift`, `BannerMessage.swift` (unchanged, still app-owned).
- Edit: `Views/NewHome/.../BannerDisplayService.swift` — `import BannerKit` (API unchanged).
- **Delete** (moved into SDK): `Views/Banner/BannerManager.swift`, `BannerProperties.swift`, `BannerToQueue.swift`, `BannerModifier.swift`, `BannerOverlayView.swift`, `BannerView.swift`, `BannerView+Preview.swift`.
- Edit wherever `BannerOverlayView()` is attached in the view tree → replace with `.bannerOverlay()` (see Task 9; grep first).
- Add `import BannerKit` to files still referencing `BannerManager`/`BannerProperties`/`BannerPosition`.

---

## Task 1: Scaffold the BannerKit package

**Files:**
- Create: `BannerKit/Package.swift`
- Create: `BannerKit/Sources/BannerKit/BannerKit.swift` (placeholder marker, deleted later)

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BannerKit",
    platforms: [.iOS(.v17), .tvOS(.v17)],
    products: [
        .library(name: "BannerKit", targets: ["BannerKit"]),
    ],
    targets: [
        .target(name: "BannerKit"),
        .testTarget(name: "BannerKitTests", dependencies: ["BannerKit"]),
    ]
)
```

- [ ] **Step 2: Add a temporary marker so the package compiles**

Create `BannerKit/Sources/BannerKit/BannerKit.swift`:

```swift
import SwiftUI
// Placeholder; replaced by real sources in later tasks.
public enum BannerKitMarker {}
```

- [ ] **Step 3: Verify the package builds standalone**

Run: `cd BannerKit && swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add BannerKit/Package.swift BannerKit/Sources/BannerKit/BannerKit.swift
git commit -m "chore(bannerkit): scaffold empty Swift package"
```

---

## Task 2: BannerPosition + Array+safe (SDK primitives)

**Files:**
- Create: `BannerKit/Sources/BannerKit/BannerPosition.swift`
- Create: `BannerKit/Sources/BannerKit/Internal/Array+safe.swift`

- [ ] **Step 1: Write `BannerPosition.swift`**

```swift
import SwiftUI

/// Where a banner anchors on screen. Replaces the implicit corner grouping that
/// used to be switched on the app's banner enum.
public enum BannerPosition: Sendable, Hashable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case bottomCenter
}
```

- [ ] **Step 2: Write `Internal/Array+safe.swift`**

```swift
extension Array {
    /// Bounds-checked subscript used by the offset math.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd BannerKit && swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add BannerKit/Sources/BannerKit/BannerPosition.swift BannerKit/Sources/BannerKit/Internal/Array+safe.swift
git commit -m "feat(bannerkit): add BannerPosition and safe-index helper"
```

---

## Task 3: BannerProperties (styling model, extended)

**Files:**
- Create: `BannerKit/Sources/BannerKit/BannerProperties.swift`

This is the app's `BannerProperties` moved into the SDK and extended with `position` (required) and an optional per-banner iOS inset override (to preserve the `favoritesEditHint` special-case as data, not a type switch).

- [ ] **Step 1: Write `BannerProperties.swift`**

```swift
import SwiftUI

/// Optional fixed EdgeInsets override for iOS positioning, used for banners whose
/// placement should not follow the default orientation-aware math.
public struct BannerInsetOverride: Sendable {
    public var portrait: EdgeInsets
    public var landscape: EdgeInsets
    public init(portrait: EdgeInsets, landscape: EdgeInsets) {
        self.portrait = portrait
        self.landscape = landscape
    }
}

public struct BannerProperties {
    public var cornerRadius: Double
    public var frame: (width: CGFloat, height: CGFloat)
    public var fillColor: Color
    public var opacity: Double
    public var showAnimation: Animation?
    public var showFrom: Edge
    public var duration: Double
    public var textColor: Color
    public var fontSize: CGFloat?
    /// Where the banner anchors on screen.
    public var position: BannerPosition
    /// Optional iOS-only fixed insets that bypass the default padding math.
    public var iOSInsetOverride: BannerInsetOverride?

    public init(
        cornerRadius: Double,
        frame: (width: CGFloat, height: CGFloat),
        fillColor: Color,
        opacity: Double,
        showAnimation: Animation?,
        showFrom: Edge,
        duration: Double,
        position: BannerPosition,
        textColor: Color = .white,
        fontSize: CGFloat? = nil,
        iOSInsetOverride: BannerInsetOverride? = nil
    ) {
        self.cornerRadius = cornerRadius
        self.frame = frame
        self.fillColor = fillColor
        self.opacity = opacity
        self.showAnimation = showAnimation
        self.showFrom = showFrom
        self.duration = duration
        self.position = position
        self.textColor = textColor
        self.fontSize = fontSize
        self.iOSInsetOverride = iOSInsetOverride
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd BannerKit && swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add BannerKit/Sources/BannerKit/BannerProperties.swift
git commit -m "feat(bannerkit): add BannerProperties with explicit position"
```

---

## Task 4: BannerPresentable protocol + BannerItem

**Files:**
- Create: `BannerKit/Sources/BannerKit/BannerPresentable.swift`
- Create: `BannerKit/Sources/BannerKit/BannerItem.swift`

- [ ] **Step 1: Write `BannerPresentable.swift`**

```swift
import SwiftUI

/// A value the host provides to describe a banner: its styling and its content.
/// Hashable identity powers duplicate suppression in the queue.
@MainActor
public protocol BannerPresentable: Hashable {
    var bannerProperties: BannerProperties { get }
    @ViewBuilder func makeContent() -> AnyView
}
```

- [ ] **Step 2: Write `BannerItem.swift`**

```swift
import Foundation
import CoreGraphics

/// One enqueued banner. Generic over the host's banner value.
public struct BannerItem<Banner: BannerPresentable>: Identifiable {
    public let id: UUID
    public let when: Date
    public let banner: Banner
    public let duration: TimeInterval
    public var offset: CGFloat

    init(id: UUID, when: Date, banner: Banner, duration: TimeInterval, offset: CGFloat = 0) {
        self.id = id
        self.when = when
        self.banner = banner
        self.duration = duration
        self.offset = offset
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd BannerKit && swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add BannerKit/Sources/BannerKit/BannerPresentable.swift BannerKit/Sources/BannerKit/BannerItem.swift
git commit -m "feat(bannerkit): add BannerPresentable protocol and BannerItem"
```

---

## Task 5: BannerManager engine (generic, TDD)

**Files:**
- Create: `BannerKit/Sources/BannerKit/BannerManager.swift`
- Test: `BannerKit/Tests/BannerKitTests/BannerManagerTests.swift`

The engine is the app's `BannerManager` generalized: generic over `Banner: BannerPresentable`, `DDLogger` replaced by an injectable `log` closure, `playerErrorCount` dropped, `[safe:]` from the SDK helper. Dedup keys on `Banner` equality (Hashable) instead of `bannerType ==`.

- [ ] **Step 1: Write the failing engine test**

```swift
import XCTest
import SwiftUI
@testable import BannerKit

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
        XCTAssertEqual(m.items.map(\.offset), [-120, -120].isEmpty ? [] : [ -120, -120 ].map { _ in 0 })
        // NOTE: replace the line above per Step 3's real offset semantics:
        // expected offsets after two enqueues are [0, -120] recalculated to the last value.
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd BannerKit && swift test`
Expected: FAIL — `cannot find 'BannerManager' in scope`.

- [ ] **Step 3: Write `BannerManager.swift`**

Port the app engine verbatim except: (a) make it generic `BannerManager<Banner: BannerPresentable>`; (b) rename `bannerToQueue` → `items`, `BannerToQueue` → `BannerItem<Banner>`, `bannerType` → `banner`; (c) dedup via `items.contains { $0.banner == banner }`; (d) replace every `DDLogger.debug/warning(...)` with `log(...)`; (e) delete `playerErrorCount` and its two mutation sites; (f) keep `calculateOffsets`/`recalculateOffsets`/`displayAndRemoveBanner`/`removeBannerAndRecalculateOffsets` byte-for-byte on the math (0, 120, 240 … 960; `-offset`; max 9).

```swift
import SwiftUI

@MainActor
public final class BannerManager<Banner: BannerPresentable>: ObservableObject {
    @Published public private(set) var items: [BannerItem<Banner>] = []
    @Published public private(set) var lastRemovedID: UUID?

    private var tasks: [UUID: Task<Void, Never>] = [:]
    private let log: (String) -> Void

    public init(log: @escaping (String) -> Void = { _ in }) {
        self.log = log
    }

    public func enqueue(_ banner: Banner, duration: TimeInterval? = nil) {
        if items.contains(where: { $0.banner == banner }) {
            log("⚠️ Duplicate banner detected, skipping")
            return
        }
        let dur = duration ?? banner.bannerProperties.duration
        let total = items.count + 1
        let offset = calculateOffsets(for: total).last ?? 0
        let item = BannerItem(id: UUID(), when: Date(), banner: banner, duration: dur, offset: offset)
        items.append(item)
        let task = Task { [weak self] in
            await self?.displayAndRemove(item)
            self?.tasks.removeValue(forKey: item.id)
        }
        tasks[item.id] = task
    }

    private func calculateOffsets(for count: Int) -> [CGFloat] {
        let steps: [CGFloat] = [0, 120, 240, 360, 480, 600, 720, 840, 960]
        let valid = min(count, steps.count)
        return (0..<valid).map { steps[$0] == 0 ? 0 : -steps[$0] }
    }

    private func displayAndRemove(_ item: BannerItem<Banner>) async {
        let delay = item.duration + 0.4
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            removeAndRecalculate(at: index)
        }
    }

    private func removeAndRecalculate(at index: Int) {
        guard let removed = items[safe: index] else { return }
        tasks[removed.id]?.cancel()
        tasks.removeValue(forKey: removed.id)
        items.remove(at: index)
        recalculateOffsets()
        lastRemovedID = removed.id
    }

    private func recalculateOffsets() {
        guard !items.isEmpty else { return }
        let offsets = calculateOffsets(for: items.count)
        for i in 0..<items.count { items[i].offset = offsets[safe: i] ?? 0 }
    }
}
```

> **Note for the engineer:** `Date()` and `UUID()` are fine in the SDK (unlike this repo's workflow scripts). The app previously used `Date.now`/`UUID()` identically.

- [ ] **Step 4: Fix the offset test to match real semantics**

Replace `testSecondBannerStacksWith120Offset` body with:

```swift
    func testSecondBannerStacksWith120Offset() {
        let m = BannerManager<StubBanner>()
        m.enqueue(StubBanner(key: "a", dur: 5))
        m.enqueue(StubBanner(key: "b", dur: 5))
        XCTAssertEqual(m.items.count, 2)
        // enqueue assigns the *last* computed offset to the newest item.
        XCTAssertEqual(m.items[1].offset, -120)
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd BannerKit && swift test`
Expected: PASS (3 tests).

- [ ] **Step 6: Commit**

```bash
git add BannerKit/Sources/BannerKit/BannerManager.swift BannerKit/Tests/BannerKitTests/BannerManagerTests.swift
git commit -m "feat(bannerkit): generic BannerManager engine with unit tests"
```

---

## Task 6: BannerModifier (position-driven, no app types)

**Files:**
- Create: `BannerKit/Sources/BannerKit/BannerModifier.swift`

Port `BannerModifier.swift`, switching on `BannerProperties.position` instead of `BannerType`. Drop the `favoritesEditHint` type-switch; instead, when `iOSInsetOverride` is set, apply those insets. Keep the tvOS fixed-padding functions verbatim (20-pt corners). Keep the iOS orientation/`visualPadding` math verbatim, but parameterize by `position` + `iOSInsetOverride` rather than banner case.

- [ ] **Step 1: Write `BannerModifier.swift`**

```swift
import SwiftUI
#if os(iOS)
import UIKit
#endif

extension View {
    @ViewBuilder
    func applyBannerModifier(position: BannerPosition, showFrom: Edge) -> some View {
        switch position {
        case .topTrailing:
            self.bannerTopTrailingPadding().transition(.move(edge: showFrom))
        case .bottomLeading:
            self.bannerBottomLeadingPadding().transition(.move(edge: showFrom))
        case .topLeading:
            self.bannerTopLeadingPadding().transition(.move(edge: showFrom))
        case .bottomTrailing:
            self.bannerBottomTrailingPadding().transition(.move(edge: showFrom))
        case .bottomCenter:
            self.bannerBottomCenteredPadding().transition(.move(edge: showFrom))
        }
    }

    func bannerTopTrailingPadding() -> some View {
        padding(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 20))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(maxHeight: .infinity, alignment: .top)
    }
    func bannerBottomTrailingPadding() -> some View {
        padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 20))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
    func bannerBottomLeadingPadding() -> some View {
        padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 0))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
    func bannerTopLeadingPadding() -> some View {
        padding(EdgeInsets(top: 20, leading: 20, bottom: 0, trailing: 0))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
    }
    func bannerBottomCenteredPadding() -> some View {
        padding(EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0))
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
```

> **iOS geometry note:** The current app has an extensive iOS `GeometryProxy` padding system (`visualPadding`, `bannerTopPadding`, orientation-aware). Port it in a **follow-up task inside this file** as `applyBannerModifier(position:showFrom:geometry:insetOverride:)`, copying the existing math verbatim and substituting `position`/`insetOverride` for the `bannerType` switches. This is the single highest-risk piece — do it as its own commit and verify visually on iPhone + iPad before proceeding. If time-boxed, ship tvOS-correct first (above) and treat the iOS geometry port as a tracked sub-task.

- [ ] **Step 2: Verify build**

Run: `cd BannerKit && swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add BannerKit/Sources/BannerKit/BannerModifier.swift
git commit -m "feat(bannerkit): position-driven banner padding/transition (tvOS)"
```

---

## Task 7: BannerView + BannerOverlayView + container modifier

**Files:**
- Create: `BannerKit/Sources/BannerKit/BannerView.swift`
- Create: `BannerKit/Sources/BannerKit/BannerOverlayView.swift`
- Create: `BannerKit/Sources/BannerKit/View+BannerOverlay.swift`

- [ ] **Step 1: Write `BannerView.swift`**

Port the tvOS branch of the app `BannerView`. Content comes from `banner.makeContent()`; styling from `banner.bannerProperties`; positioning from `applyBannerModifier(position:showFrom:)`. Replace `DDLogger` with nothing (or the manager's logger if threaded).

```swift
import SwiftUI

struct BannerView<Banner: BannerPresentable>: View {
    let banner: Banner
    @State private var visible = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        let props = banner.bannerProperties
        ZStack {
            if visible {
                banner.makeContent()
                    .applyBannerModifier(position: props.position, showFrom: props.showFrom)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            withAnimation(props.showAnimation) { visible = true }
            dismissTask?.cancel()
            dismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(props.duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(props.showAnimation) { visible = false }
            }
        }
        .onDisappear { dismissTask?.cancel(); dismissTask = nil }
    }
}
```

- [ ] **Step 2: Write `BannerOverlayView.swift`**

```swift
import SwiftUI

struct BannerOverlayView<Banner: BannerPresentable>: View {
    @ObservedObject var manager: BannerManager<Banner>

    var body: some View {
        ZStack {
            ForEach(manager.items.sorted { $0.when < $1.when }) { item in
                BannerView(banner: item.banner)
                    .offset(y: item.offset)
            }
        }
    }
}
```

> **iOS note:** add the iPhone/iPad `GeometryReader` + `bannerScaleFactor` (0.5 iPad / 0.4 iPhone) branch from the app's `BannerOverlayView`, gated by `#if os(iOS)`, when porting the iOS geometry system in Task 6.

- [ ] **Step 3: Write `View+BannerOverlay.swift`**

```swift
import SwiftUI

public extension View {
    /// Overlays the banner stack driven by `manager` on top of this view.
    func bannerOverlay<Banner: BannerPresentable>(_ manager: BannerManager<Banner>) -> some View {
        overlay(BannerOverlayView(manager: manager))
    }
}
```

- [ ] **Step 4: Verify build**

Run: `cd BannerKit && swift build`
Expected: `Build complete!`

- [ ] **Step 5: Delete the placeholder + commit**

```bash
rm BannerKit/Sources/BannerKit/BannerKit.swift
git add -A BannerKit/
git commit -m "feat(bannerkit): banner rendering views and bannerOverlay modifier"
```

---

## Task 8: Add BannerKit to the Xcode project

**Files:**
- Modify: `iptvFaves.xcodeproj/project.pbxproj` (via ruby)

- [ ] **Step 1: Add the local package + link it to the app target**

Create `scripts/add_bannerkit.rb`:

```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('iptvFaves.xcodeproj')
app = project.targets.find { |t| t.name == 'iptvFaves' && t.product_type == 'com.apple.product-type.application' }

ref = project.root_object.package_references.find { |r| r.respond_to?(:relative_path) && r.relative_path == 'BannerKit' }
unless ref
  ref = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  ref.relative_path = 'BannerKit'
  project.root_object.package_references << ref
end

dep = app.package_product_dependencies.find { |d| d.product_name == 'BannerKit' }
unless dep
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.product_name = 'BannerKit'
  dep.package = ref
  app.package_product_dependencies << dep
  app.frameworks_build_phase.add_file_reference(
    project.new(Xcodeproj::Project::Object::PBXBuildFile).tap { |bf| bf.product_ref = dep }
  ) rescue nil
end

project.save
puts 'BannerKit linked to iptvFaves target'
```

Run: `ruby scripts/add_bannerkit.rb`
Expected: `BannerKit linked to iptvFaves target`

- [ ] **Step 2: Verify the app still builds (before any app edits)**

Run:
```bash
xcodebuild -scheme iptvFaves -configuration Debug -destination 'generic/platform=tvOS Simulator' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add iptvFaves.xcodeproj/project.pbxproj scripts/add_bannerkit.rb
git commit -m "build: add local BannerKit package to the app target"
```

---

## Task 9: Conform app BannerType to BannerPresentable; delete moved engine files

**Files:**
- Modify: `iptvFaves/Views/Banner/BannerType.swift`
- Delete: `BannerManager.swift`, `BannerProperties.swift`, `BannerToQueue.swift`, `BannerModifier.swift`, `BannerOverlayView.swift`, `BannerView.swift`, `BannerView+Preview.swift` (all under `iptvFaves/Views/Banner/`)
- Modify: any file attaching `BannerOverlayView()` (grep), `BannerDisplayService.swift`
- Modify: `iptvFaves.xcodeproj/project.pbxproj` (de-wire deleted files via ruby, same pattern as prior removals)

- [ ] **Step 1: Rewrite `BannerType.swift` to conform**

Add `import BannerKit`. Give every `BannerProperties(...)` a `position:` argument (mapping below) and, for `favoritesEditHint`, an `iOSInsetOverride`. Add `makeContent()` moving the `bannerContent()` switch here.

Position mapping (from the old corner grouping):
- `.channelName`, `.add2favesFailed`, `.exportSuccess` → `.topTrailing`
- `.favoritesEditHint` → `.bottomLeading` (+ `iOSInsetOverride` portrait `top:160,trailing:40`, landscape `60/60` — copy from old `bannerTopPadding`/`bannerTrailingPadding` special-case)
- `.m3uItemDetails` → `.topLeading`
- `.playerError`, `.exportFailed`, `.metadata` → `.bottomTrailing` (metadata keeps `showFrom: .bottom`)

```swift
import SwiftUI
import BannerKit

enum BannerType: Equatable, Hashable {
    case channelName(_ message: String)
    case favoritesEditHint(_ message: String)
    case add2favesFailed(_ message: String)
    case playerError(_ error: String)
    case m3uItemDetails(_ m3uItem: M3uItem)
    case metadata(_ array: [String])
    case exportSuccess(_ message: String)
    case exportFailed(_ message: String)
}

extension BannerType: BannerPresentable {
    var bannerProperties: BannerProperties {
        switch self {
        case .channelName:
            return BannerProperties(cornerRadius: 25, frame: (380, 160), fillColor: .blue,
                opacity: 0.9, showAnimation: .easeInOut(duration: 0.3), showFrom: .trailing,
                duration: BannerDuration.anyString, position: .topTrailing)
        case .favoritesEditHint:
            return BannerProperties(cornerRadius: 25, frame: (620, 100), fillColor: .yellow,
                opacity: 0.9, showAnimation: .easeInOut(duration: 0.3), showFrom: .leading,
                duration: BannerDuration.anyString, position: .bottomLeading,
                textColor: .black, fontSize: FontSizes.banners,
                iOSInsetOverride: BannerInsetOverride(
                    portrait: EdgeInsets(top: 160, leading: 20, bottom: 0, trailing: 40),
                    landscape: EdgeInsets(top: 60, leading: 20, bottom: 0, trailing: 60)))
        case .add2favesFailed:
            return BannerProperties(cornerRadius: 25, frame: (380, 120), fillColor: .red,
                opacity: 0.9, showAnimation: .easeInOut(duration: 0.4), showFrom: .trailing,
                duration: BannerDuration.add2favesFailed, position: .topTrailing)
        case .playerError:
            return BannerProperties(cornerRadius: 25, frame: (700, 100), fillColor: .red,
                opacity: 0.9, showAnimation: .spring(response: 0.5, dampingFraction: 0.6),
                showFrom: .trailing, duration: BannerDuration.playerError, position: .bottomTrailing)
        case .m3uItemDetails:
            return BannerProperties(cornerRadius: 25, frame: (660, 250), fillColor: .gray,
                opacity: 0.9, showAnimation: .easeInOut(duration: 0.5), showFrom: .leading,
                duration: BannerDuration.m3uItemDetails, position: .topLeading)
        case .metadata:
            return BannerProperties(cornerRadius: 25, frame: (300, 120), fillColor: .blue,
                opacity: 0.7, showAnimation: .easeInOut(duration: 0.3), showFrom: .bottom,
                duration: BannerDuration.metadata, position: .bottomTrailing)
        case .exportSuccess:
            return BannerProperties(cornerRadius: 25, frame: (380, 120), fillColor: .green,
                opacity: 0.9, showAnimation: .easeInOut(duration: 0.3), showFrom: .trailing,
                duration: BannerDuration.anyString, position: .topTrailing)
        case .exportFailed:
            return BannerProperties(cornerRadius: 25, frame: (380, 120), fillColor: .red,
                opacity: 0.9, showAnimation: .easeInOut(duration: 0.3), showFrom: .trailing,
                duration: BannerDuration.playerError, position: .bottomTrailing)
        }
    }

    @ViewBuilder func makeContent() -> AnyView {
        switch self {
        case .channelName(let s), .favoritesEditHint(let s), .exportSuccess(let s):
            AnyView(M3uItemTitleView(string: s, bannerProperties: bannerProperties))
        case .add2favesFailed(let m):
            AnyView(Add2favesFailedView(message: m, bannerProperties: bannerProperties))
        case .playerError(let e), .exportFailed(let e):
            AnyView(PlayerErrorView(error: e, bannerProperties: bannerProperties))
        case .m3uItemDetails(let item):
            AnyView(M3uItemDetailsView(m3uItem: item, bannerProperties: bannerProperties))
        case .metadata(let arr):
            AnyView(MetadataView(array: arr, bannerProperties: bannerProperties))
        }
    }
}
```

> **Content-view signatures:** the content views currently take `bannerProperties: BannerProperties`. Since `BannerProperties` now lives in `BannerKit`, add `import BannerKit` to each content-view file (`M3uItemTitleView`, `Add2favesFailedView`, `PlayerErrorView`, `M3uItemDetailsView`, `MetadataView`). Grep for their definitions first.

- [ ] **Step 2: Provide the app's shared manager instance**

Create `iptvFaves/Views/Banner/AppBannerManager.swift`:

```swift
import BannerKit

/// App-wide banner manager (was BannerManager.shared).
@MainActor let appBannerManager = BannerManager<BannerType>(log: { message in
    DDLogger.debug(message, category: .ui)
})
```

- [ ] **Step 3: Migrate the call sites (compatibility shim keeps them unchanged)**

Add to the same file an API-compatible shim so the 8 existing call sites don't churn:

```swift
extension BannerManager where Banner == BannerType {
    static var shared: BannerManager<BannerType> { appBannerManager }
    func addBannerToQueue(bannerType: BannerType, duration: TimeInterval? = nil) {
        enqueue(bannerType, duration: duration)
    }
}
```

> This preserves `BannerManager.shared.addBannerToQueue(bannerType:duration:)` verbatim. Add `import BannerKit` to the ~8 caller files (grep list in Task 10).

- [ ] **Step 4: Replace the overlay attachment**

Grep for where `BannerOverlayView()` is placed in the view tree:
Run: `grep -rn "BannerOverlayView" iptvFaves --include="*.swift"`
Replace each `BannerOverlayView()` usage with `.bannerOverlay(appBannerManager)` on the appropriate root/container view. (Likely in `HubView`/`NewHomeViewBase` — confirm via grep.)

- [ ] **Step 5: Delete the moved engine files from disk + de-wire pbxproj**

```bash
git rm iptvFaves/Views/Banner/BannerManager.swift \
       iptvFaves/Views/Banner/BannerProperties.swift \
       iptvFaves/Views/Banner/BannerToQueue.swift \
       iptvFaves/Views/Banner/BannerModifier.swift \
       iptvFaves/Views/Banner/BannerOverlayView.swift \
       iptvFaves/Views/Banner/BannerView.swift \
       iptvFaves/Views/Banner/BannerView+Preview.swift
```

Then de-wire them from the target with a ruby script (same `remove_from_project` pattern used for the NetworkLayer removal in commit `f713f68`).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: adopt BannerKit; BannerType conforms to BannerPresentable"
```

---

## Task 10: Build both platforms, run suite, smoke test

**Files:** none (verification)

- [ ] **Step 1: Confirm all banner callers import BannerKit**

Run: `grep -rln "BannerManager\|BannerProperties\|BannerPosition" iptvFaves --include="*.swift"`
For each hit, ensure `import BannerKit` is present. Known callers:
`PVM+ErrorHandling.swift`, `MainChannelsListViewModel+Search.swift`, `MainChannelsListViewModel+Faves.swift`, `NHC+exportFavoritesAndUpload.swift`, `BannerDisplayService.swift`, `M3uListInputViewModel.swift` (commented), plus the content views and the overlay host.

- [ ] **Step 2: Build tvOS**

Run: `xcodebuild -scheme iptvFaves -configuration Debug -destination 'generic/platform=tvOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Build iOS**

Run: `xcodebuild -scheme iptvFaves -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the app suite (must stay green)**

Run:
```bash
xcodebuild test -scheme iptvFaves -configuration Debug \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -only-testing:iptvFavesTests -parallel-testing-enabled NO 2>&1 \
  | grep -E "Executed [0-9]+ tests, with|\*\* TEST"
```
Expected: `Executed 252 tests, with 0 failures` · `** TEST SUCCEEDED **`

- [ ] **Step 5: Run the package's own tests**

Run: `cd BannerKit && swift test`
Expected: PASS.

- [ ] **Step 6: Manual smoke (tvOS + iPhone + iPad)**

Trigger each banner and confirm placement/animation unchanged vs. `main`:
- playerError (open a dead channel) — bottom-trailing, red.
- favoritesEditHint (long-press in faves) — bottom-leading, yellow, black text.
- exportSuccess/exportFailed (export favorites) — top-trailing.
- m3uItemDetails — top-leading.
On iOS verify both orientations on iPhone and iPad (this exercises the ported geometry math).

- [ ] **Step 7: Final commit**

```bash
git commit --allow-empty -m "test: verify BannerKit extraction — both platforms build, suite green (252)"
```

---

## Self-Review notes (for the executor)

- **Highest risk:** the iOS `GeometryProxy` padding/scale system (Task 6 iOS note + Task 7 iOS note). It is pure layout math keyed off position + the one inset override; port it verbatim and verify visually before considering the extraction done. If it must be deferred, ship tvOS-correct and track the iOS geometry port as a follow-up — do NOT approximate it.
- **Type consistency:** `items`/`banner`/`enqueue` names are used identically across Tasks 4–9. The compatibility shim (`addBannerToQueue`, `.shared`) keeps the 8 call sites byte-for-byte.
- **Dedup semantics change:** old code deduped on `bannerType ==`; new code deduped on `Banner` `Hashable`. For `BannerType` these are equivalent (it's already `Equatable/Hashable`), so behavior is preserved.
- **Dropped:** `playerErrorCount` (write-only, never read externally) and `reset()` (private, unused) — omit from the SDK; if a caller references them, surface it rather than porting dead code.
- **Not moved:** `BannerDuration`, `BannerMessage`, and all content views stay app-side (they encode app copy/branding). The SDK stays content-agnostic.
```
