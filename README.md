# A1R2Banner

A content-agnostic SwiftUI banner SDK for the Liquid Glass era. The SDK owns the
*engine* (a queue with dedup, per-position stacking, timed auto-removal) and the
*layout*; the host owns the *content* and *styling*. Ships a batteries-included
**Liquid Glass** banner (`GlassBanner`) you can drop in with one line.

**Platforms:** iOS 26 · tvOS 26 · macOS 26 · Xcode 26+ (Swift tools 6.2).

## Install

Swift Package Manager — add the package (local path shown):

```swift
.package(path: "../a1r2-banner")
// target dependency: .product(name: "A1R2Banner", package: "A1R2Banner")
```

## Quick start

### 1 — Drop in `GlassBanner` (zero boilerplate)

```swift
import A1R2Banner

@StateObject private var banners = BannerManager<GlassBanner>()

// …attach once on a root/container view:
someRootView.bannerOverlay(banners)

// …fire it:
banners.enqueue(GlassBanner(
    title: "Saved to Favorites",
    subtitle: "Find it under the Favorites tab",
    systemImage: "star.fill",
    tint: .yellow
))
```

`GlassBanner` renders a real Liquid Glass capsule that morphs open from the top
(Dynamic-Island style), refracts the content behind it, is interactive, and gives
a soft haptic on iPhone. It anchors at `.topCenter` and is a singleton — a newer
one replaces the current.

### 2 — Bring your own banner type

Conform any `Hashable` value to `BannerPresentable`:

```swift
enum MyBanner: Hashable { case saved, error(String) }

extension MyBanner: BannerPresentable {
    var bannerProperties: BannerProperties {
        BannerProperties(
            cornerRadius: 16, frame: (width: 320, height: 64),
            fillColor: .accentColor, opacity: 1, showAnimation: .smooth,
            showFrom: .trailing, duration: 3, position: .bottomTrailing,
            stacks: true                     // opt into piling (see below)
        )
    }
    func makeContent() -> AnyView { AnyView(MyBannerView(banner: self)) }
}

let banners = BannerManager<MyBanner>(log: { print($0) })
banners.enqueue(.saved)                      // duration from the banner
banners.enqueue(.error("boom"), duration: 4) // explicit override
```

The SDK never draws your text — `makeContent()` does — so color, font, and layout
are entirely yours. `BannerProperties` also carries styling data
(`fillColor`, `textColor`, `fontSize`, `font`, `cornerRadius`, …) for your content
to honor.

## Stacking: singletons by default, opt-in bottom piling

Piling is **opt-in and bottom-only**:

| Situation | Behavior |
|---|---|
| Default (`stacks: false`) | **Singleton** — a new banner replaces whatever is already at its position. No overlap, nothing off-screen. |
| **Top** anchors (`.topLeading/.topTrailing/.topCenter`) | **Never pile**, even with `stacks: true` — a top pile would climb off-screen. Always singleton. |
| **Bottom** anchors + `stacks: true` | Pile upward *into* the screen; spacing is derived from each banner's height + a fixed gap (not a magic ladder). |

Banners at different positions are always independent. On iOS the stacking offset
scales by the banner's own `iOSScale` (default `nil` = the legacy 0.5 iPad / 0.4
iPhone downscale for tvOS-sized art; `GlassBanner` uses `1` for native sizing).

## Positioning & placement

- **`BannerPosition`** — `.topLeading/.topTrailing/.topCenter`,
  `.bottomLeading/.bottomTrailing/.bottomCenter`. `.topCenter` is the iPhone
  Dynamic-Island slot.
- **`BannerPlacement`** (iOS `BannerView` param) — `.adaptive` (full-screen
  overlay, geometry-aware) or `.fixed` (fixed corner insets for a banner rendered
  inside a **bounded container** as an `.overlay`, so it hugs *that* container's
  corner). tvOS/macOS are always fixed.

## API reference

| Symbol | Role |
|---|---|
| `BannerPresentable` | The seam: `Hashable` (dedup) + `bannerProperties` + `makeContent()`. |
| `BannerManager<Banner>` | `@MainActor ObservableObject` engine: `enqueue(_:duration:)`, `clear()`, `@Published items`. |
| `BannerProperties` | Styling + `position`, `stacks`, `iOSScale`, `duration`, `font`/`fontSize`. |
| `BannerPosition` / `BannerPlacement` | Anchor + iOS placement mode. |
| `View.bannerOverlay(_:)` | Attach a manager's overlay once on a root view. |
| `BannerView` | Render a single banner (used by the overlay; also usable directly). |
| `GlassBanner` / `GlassBannerContent` | Drop-in Liquid Glass banner value + its reusable content view. |

## Tests

`swift test` — 23 tests covering dedup, height-derived per-position stacking,
top-never-piles, singleton-replace, timed removal, and the `GlassBanner` data
contract.

## Status

Extracted from the iptvFaves app; developed standalone (see the companion
`a1r2-banner-starter` gallery). Evolving — the API may still be refined.
