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
            frame: .zero,                         // legacy content hint; actual size is measured
            duration: 3,
            position: .bottomTrailing,
            cornerRadius: 18,
            fillColor: .blue,
            showFrom: .trailing,
            stacks: true)          // opt into bottom piling
    }

    func makeContent() -> some View {              // return a concrete view — no AnyView
        Label(text, systemImage: "info.circle.fill")
            .padding().foregroundStyle(bannerProperties.textColor)
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
| **Bottom** anchors + `stacks: true` | Pile upward inside the host region; spacing uses actual measured heights plus `BannerManager(stackGap:)`. A region too short for the whole pile clips the excess. |

Banners at different positions are always independent.

---

## Host-constrained layout

**The host defines the available region. The banner adapts to that region.**
Attach `.bannerOverlay(manager)` to the container where banners may exist. The
SDK uses its local SwiftUI proposal, intrinsic content sizes and semantic
leading/trailing alignment. It never consults device identity, screen resolution,
orientation names or global screen bounds.

- `BannerPosition` chooses one of six anchors **inside the host region**.
- `BannerProperties.maximumWidth` is a preferred upper bound, default **560 pt**.
  Short intrinsic content stays short; the parent can always offer less. Custom
  banner types can override this independently of platform.
  The cap is a notification readability/design preference, not a device preset:
  it limits line length on very wide hosts while preserving intrinsic short content.
- Native layout is the default. Text wraps/truncates normally. Bottom stacks use
  measured heights, including changes due to wrapping or Dynamic Type.
- A local decorative inset is at most 20 pt per edge and decreases in very small
  regions. It does not replace the host's safe margins or reserved control areas.
- Bounded surfaces clip content that refuses the proposal (for example an explicit
  `.frame(width: 900)` or a narrow HStack's minimum width), and bound hit testing.
  The SDK cannot reflow an intentionally fixed custom view. Prefer flexible frames
  and avoid horizontal `.fixedSize()` for text. If height is insufficient, content
  is truncated/clipped; the SDK does not shrink Dynamic Type to make everything fit.
- Safe-area policy belongs to the host on **every** platform, including tvOS.
  The SDK never calls `.ignoresSafeArea()` or reserves space for app controls.

### Migrating from device scaling

Previously, `renderScale: nil` meant 0.4 on iPhone, 0.5 on iPad and 1 elsewhere.
This was documented public behavior. It now means **1 everywhere**. The old
`scaleEffect` changed rendering while leaving the negotiated layout footprint
unchanged. Existing calls compile, but banners relying on implicit downscaling
will change size. Rewrite those views to use native fonts and flexible layout.
The 560-point default cap also applies on tvOS; legacy artwork that intentionally
needs more room can choose a different `maximumWidth` in its banner properties.

Explicit `renderScale` remains supported on every platform for legacy artwork.
Both its measurement proposal and reported footprint now account for that scale;
it never selects a scale based on device identity. Positive finite scales are
honored without an arbitrary range cutoff; other values fall back to 1. Invalid/nonfinite
width limits fall back to 560; negative limits become zero. `frame` remains a
custom-content hint, and the manager retains internal legacy offset estimates,
but rendered stacks no longer use those estimates. A direct `BannerView`'s
legacy `stackOffset` is a host-point reservation clamped inside its region.

### Foreground ownership

`GlassBanner` defaults title, subtitle and symbol to **white**, using one shared
`textColor`. Override it with `GlassBanner(title: "Saved", textColor: .yellow)`.
The tint still colors the glass; the symbol now matches the text. A dark backing
under the translucent glass helps keep white readable over light host content.
Callers choosing other foregrounds/tints remain responsible for their contrast.

`BannerProperties.textColor` already existed as a custom-content styling hint;
its default changes from `.primary` to `.white`. Custom `makeContent()` still
owns its styling and inherits the host environment normally. The renderer does
not force white onto arbitrary content. Honor the hint with
`.foregroundStyle(bannerProperties.textColor)`, or set a deliberate child style.
Existing explicit overrides continue to work. Original initializer signatures
are retained through forwarding overloads, including typed function references.
The new foreground and sizing overrides are additive, with intentional visual/default
behavior changes.

### Host integration example

```swift
playerOverlayRegion                 // the app derives this region
    .bannerOverlay(banners)         // SDK receives only its local rectangle
```

For iptvFaves, update the package revision after publication, provide a bounded
player-overlay container avoiding Close/Debug controls, and replace fixed-width
custom banner frames with flexible content. Remove per-device scale calculation;
use `maximumWidth` only for an intentional design preference. No iptvFaves code
is changed in this repository.

The same contract covers split views, resized windows and a foldable host's
usable rectangle without hinge or device checks. It is portable to spatial
containers, but **the full package does not currently support visionOS**:
`Package.swift` declares iOS/tvOS/macOS 26, and its Liquid Glass APIs are explicitly
unavailable in the installed visionOS 27 SDK. No deployment targets were changed.

---

## API reference

| Symbol | Role |
|---|---|
| `BannerManager<Banner>` | `@MainActor ObservableObject` engine. `enqueue(_:duration:)`, `dismiss(id:)`, `clear()`, `@Published items`, `@Published lastRemovedID`. `init(stackGap:log:)`. |
| `BannerPresentable` | The seam your type conforms to: `Hashable` (dedup) + `bannerProperties` + `makeContent()`. |
| `BannerProperties` | Styling + `position`, `duration`, `stacks`, `renderScale`, `maximumWidth`, `frame` (legacy content hint), `font`/`fontSize`, `accessibilityLabel`, … |
| `BannerPosition` | Six semantic anchors inside the host region. |
| `BannerView(banner:duration:stackOffset:)` | Direct rendering without a manager. Optional duration override. The deprecated iOS placement initializer remains available. |
| `BannerItem<Banner>` | Read-only public `id`, `when`, `banner`, `duration`; created by the manager. |
| `BannerPlacement` | Legacy `.adaptive` / `.fixed` compatibility enum; has no effect. |
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
+ two `bannerOverlay`s), `DemoBanner.swift` (a flexible custom `BannerPresentable`),
and `LayoutGallery.swift` (arbitrary-width review fixtures). Launch with
`--layout-review` for a stable gallery showing white foreground, an explicit
orange override, and 120/240/360/560-point containers. Add `--light` for a white
host in Light Mode; the default gallery uses Dark Mode. System simulator screenshots
capture the composited glass more reliably than view-hierarchy raster capture.

---

## Architecture and platform audit

The rendering chain is `View.bannerOverlay` → `BannerOverlayView` → one
`BannerRegionLayout` per anchor → `BannerPresentation` → `BannerContentLayout` →
`BannerPresentable.makeContent()`. A direct `BannerView` uses the same region and
presentation path. `GlassBanner` returns the reusable `GlassBannerContent`;
custom banner values can return any concrete SwiftUI view or `AnyView`.

`BannerManager` owns de-duplication, singleton replacement, bottom-only piling,
the nine-item cap and task-based removal with a 0.4-second exit grace. The view
owns its show/dismiss cycle and honors a per-enqueue duration override. Layout
reads the manager's gap and measures content; queue offset estimates are retained
internally but no longer determine rendered placement.

There is no SDK `GeometryReader`, global-screen lookup, orientation lookup or
physical-device sizing branch. The original iOS-only `UIDevice` idiom check has
been removed. Remaining platform conditionals preserve only the deprecated iOS
placement initializer and iOS haptic feedback in glass content. The package
manifest remains iOS 26 / tvOS 26 / macOS 26, Swift tools 6.2, Swift 5 language mode.
Starter declares iOS/tvOS 26. No new platform support is claimed by omission of a
platform declaration.

Glass content uses semantic text fonts (including the symbol), leading-aligned
multiline text, local padding and its capsule glass/background/sheen. The old
unrestricted horizontal `fixedSize` and fixed 18-point / 30-point symbol metrics
are gone. The only remaining explicit content scale is opt-in legacy artwork;
icon/reveal scale transitions remain visual animations. Slide/opacity transitions,
Reduce Motion branches, iOS haptics and accessibility announcements are retained.
A provided accessibility label continues to replace descendant accessibility
labels; leave it nil when custom controls should expose their own semantics.

The layout adds no focus policy, gesture recognizer, touch-only control or pointer
assumption. Custom controls keep normal SwiftUI interaction. Glass retains its
interactive visual effect. The host owns tvOS safe/overscan margins; unlike the
old renderer, the SDK does not escape that region. Full physical remote, pointer,
VoiceOver and Reduce Motion preference testing still require interactive testing.

## Tests

```bash
swift test
```

Tests cover queue behavior, finite sizing policy, foreground defaults/overrides,
real SwiftUI hosting, explicit scale measurement, narrow/short regions, wrapping,
RTL anchors, continuous resizing, measured stacking, background rasterization and
(macOS) clicks outside clipped content. Raster tests attach PNGs to XCTest results;
macOS also writes them to its temporary `A1R2BannerLayoutTests` directory.

To build Starter and run these tests on an iOS/tvOS simulator without installing
XcodeGen, generate a disposable project:

```bash
python3 Validation/generate-project.py /private/tmp/A1R2Validation
xcodebuild -project /private/tmp/A1R2Validation/A1R2BannerStarter.xcodeproj \
  -scheme A1R2BannerStarter -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /private/tmp/A1R2Validation/ios -parallel-testing-enabled NO test
```

Use a tvOS simulator destination for the TV suite. The generator uses the package
and Starter sources directly; it changes no package deployment targets.

---

## License

MIT — see [LICENSE](LICENSE).

---

## Status

Extracted from the iptvFaves app and developed standalone. The public surface is
stable but still evolving; pin a commit if you depend on it.
