# A1R2Banner

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2026%20%C2%B7%20tvOS%2026%20%C2%B7%20macOS%2026-0A84FF)](#)
[![SPM](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen)](https://swift.org/package-manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

A content-agnostic SwiftUI banner SDK for the Liquid Glass era. The SDK owns the
**engine** (a queue with de-duplication, per-position stacking, and timed
auto-removal) and the **layout**; your app owns the **content** and **styling**.
It ships a batteries-included **Liquid Glass** banner (`GlassBanner`) you can drop
in with a single line.

**Platforms:** iOS 26 · tvOS 26 · macOS 26 · Swift tools 6.2 (Xcode 26+).

---

## Install

### Xcode

**File ▸ Add Package Dependencies…**, then paste:

```
https://github.com/a1r2/A1R2Banner.git
```

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/a1r2/A1R2Banner.git", branch: "main"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "A1R2Banner", package: "A1R2Banner"),
        ]),
]
```

The public surface is stable but still pre-1.0, so `branch: "main"` tracks the
tip. To pin instead, use `.package(url: ..., revision: "<commit-sha>")`.

---

## Quick start

### 1 — Drop in `GlassBanner` (zero boilerplate)

```swift
import A1R2Banner

struct ContentView: View {
    @StateObject private var banners = BannerManager<GlassBanner>()

    var body: some View {
        MyRootView()
            .bannerOverlay(banners)            // attach once, on a root/container view
    }

    func showSaved() {
        banners.enqueue(GlassBanner(
            title: "Saved to Favorites",
            subtitle: "Find it under the Favorites tab",
            systemImage: "star.fill",
            tint: .yellow))
    }
}
```

`GlassBanner` renders a real Liquid Glass capsule that morphs open from the top
(Dynamic-Island style on iPhone) and refracts what's behind it. It anchors at
`.topCenter` and is a singleton — a newer one replaces the current.

### 2 — Bring your own banner type

Conform any `Hashable` value to `BannerPresentable`. You return the styling
(`bannerProperties`) and the content (`makeContent()`); the SDK never draws your
text, so the look is entirely yours.

```swift
enum Toast: Hashable { case info(String) }

extension Toast: BannerPresentable {
    var bannerProperties: BannerProperties {
        BannerProperties(
            frame: CGSize(width: 360, height: 66),   // only height feeds stacking math
            duration: 3,
            position: .bottomTrailing,
            cornerRadius: 18,
            fillColor: .blue,
            showFrom: .trailing,
            renderScale: 1,        // laid out natively — see "renderScale" below
            stacks: true)          // opt into bottom piling
    }

    func makeContent() -> some View {              // return a concrete view — no AnyView
        Label(text, systemImage: "info.circle.fill")
            .padding().foregroundStyle(.white)
    }
    private var text: String { if case .info(let m) = self { m } else { "" } }
}

let toasts = BannerManager<Toast>(log: { print($0) })
toasts.enqueue(.info("Hello"))                  // duration comes from the banner
toasts.enqueue(.info("Override"), duration: 5)  // …or override per-enqueue
```

A complete, runnable example (iOS + tvOS) lives in **[`Starter/`](Starter/)** — see
below.

---

## Stacking: singletons by default, opt-in bottom piling

| Situation | Behavior |
|---|---|
| Default (`stacks: false`) | **Singleton** — a new banner replaces whatever is at its position. Nothing overlaps or runs off-screen. |
| **Top** anchors (`.topLeading` / `.topTrailing` / `.topCenter`) | **Never pile**, even with `stacks: true` — a top pile would climb into the status bar / Island. Always singleton. |
| **Bottom** anchors + `stacks: true` | Pile upward *into* the screen; spacing is derived from each banner's `frame.height` plus a fixed `stackGap` (configurable via `BannerManager(stackGap:)`). |

Banners at different positions are always independent.

---

## Positioning & scaling

- **`BannerPosition`** — `.topLeading` · `.topTrailing` · `.topCenter` ·
  `.bottomLeading` · `.bottomTrailing` · `.bottomCenter`. `.topCenter` is the
  iPhone Dynamic-Island slot. The layout is unified and safe-area aware on every
  platform (tvOS hugs the physical edge).
- **`renderScale`** — a scale applied to your content on iOS. `nil` (default)
  keeps the legacy device downscale (0.5 iPad / 0.4 iPhone) for banners designed
  at tvOS size; set `1` for content laid out natively for iOS (as `GlassBanner`
  does). tvOS/macOS always use `1`.

---

## API reference

| Symbol | Role |
|---|---|
| `BannerManager<Banner>` | `@MainActor ObservableObject` engine. `enqueue(_:duration:)`, `dismiss(id:)`, `clear()`, `@Published items`, `@Published lastRemovedID`. `init(stackGap:log:)`. |
| `BannerPresentable` | The seam your type conforms to: `Hashable` (dedup) + `bannerProperties` + `makeContent()`. |
| `BannerProperties` | Styling + `position`, `duration`, `stacks`, `renderScale`, `frame` (height feeds stacking), `font`/`fontSize`, `accessibilityLabel`, … |
| `BannerPosition` | Where a banner anchors on screen. |
| `View.bannerOverlay(_:)` | Attach a manager's overlay once on a root view. |
| `GlassBanner` / `GlassBannerContent` | The drop-in Liquid Glass banner value + its reusable content view (use the content from your own type via `makeContent()` to get the look without adopting `GlassBanner`). |

Accessibility: set `BannerProperties.accessibilityLabel` (or use `GlassBanner`,
which derives it) to have the banner announced to VoiceOver on appear; the SDK
honors Reduce Motion.

---

## Starter example

A runnable SwiftUI app (iOS **and** tvOS) that exercises both paths —
`GlassBanner` and a custom `BannerPresentable`, including bottom stacking.

The Xcode project is generated from `Starter/project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (so it's never stale and never
committed). Generate it, then open:

```bash
brew install xcodegen          # once, if you don't have it
cd Starter
xcodegen generate
open A1R2BannerStarter.xcodeproj
```

Files: `A1R2BannerStarterApp.swift` (entry point), `ContentView.swift` (the demo UI
+ two `bannerOverlay`s), `DemoBanner.swift` (a custom `BannerPresentable`).

---

## Tests

```bash
swift test
```

34 tests covering de-duplication, height-derived per-position stacking,
top-never-piles, singleton-replace, timed removal, task cancellation, and the
`GlassBanner` data contract.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Status

Extracted from the iptvFaves app and developed standalone. The public surface is
stable but still evolving; pin a commit if you depend on it.
