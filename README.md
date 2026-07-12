# A1R2Banner

A small, content-agnostic SwiftUI banner engine: a queue with duplicate
suppression and vertical stacking, plus position-driven rendering for tvOS and
iOS/iPadOS. The host app owns the banner *content* and *styling*; the SDK owns
the *engine* and *layout*.

## Concept

The host describes each banner by conforming its own type to `BannerPresentable`:

```swift
import A1R2Banner

extension MyBanner: BannerPresentable {
    var bannerProperties: BannerProperties { /* styling + position */ }
    func makeContent() -> AnyView { /* the app's view */ }
}
```

Create one manager and drive it:

```swift
@MainActor let banners = BannerManager<MyBanner>(log: { print($0) })

banners.enqueue(.somethingHappened)           // duration from the banner
banners.enqueue(.error("boom"), duration: 4)  // explicit override
```

Attach the overlay once, on a root/container view:

```swift
someRootView
    .bannerOverlay(banners)
```

## Design

- **`BannerPresentable`** — the seam. `Hashable` identity powers duplicate
  suppression; `bannerProperties` gives styling + `position`; `makeContent()`
  returns the app's view.
- **`BannerManager<Banner>`** — `@MainActor ObservableObject`: enqueue, dedup,
  offset stacking (0, −120, −240 … up to 9), timed auto-removal, injectable log.
- **`BannerProperties` / `BannerPosition`** — styling model + explicit anchor.
- **`BannerView` / `BannerOverlayView` / `.bannerOverlay(_:)`** — rendering.

Platform layout: tvOS uses fixed 20-pt corner insets; iOS/iPadOS uses
orientation- and idiom-aware geometry padding with a compensating `scaleEffect`
(0.5 iPad / 0.4 iPhone).

## Status

Extracted from the iptvFaves app. Evolving — expect the API to be refined.
