// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// Each anchor has its own measured region. The host owns safe-area policy.
struct BannerOverlayView<Banner: BannerPresentable>: View {
    @ObservedObject var manager: BannerManager<Banner>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BannerRegionLayout(spacing: manager.layoutStackGap) {
            ForEach(manager.items.sorted { $0.when < $1.when }) { item in
                BannerPresentation(banner: item.banner, duration: item.duration)
                    .layoutValue(key: BannerPositionKey.self, value: item.banner.bannerProperties.position)
                    .layoutValue(key: BannerStacksKey.self, value: item.banner.bannerProperties.stacks)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .modifier(BannerHostHits())
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
    }
}
