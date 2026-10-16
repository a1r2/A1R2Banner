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

    private let positions: [BannerPosition] = [
        .topLeading, .topCenter, .topTrailing, .bottomLeading, .bottomCenter, .bottomTrailing
    ]

    var body: some View {
        ZStack {
            ForEach(positions, id: \.self) { position in
                BannerRegionLayout(position: position, spacing: manager.layoutStackGap) {
                    ForEach(manager.items.filter { $0.banner.bannerProperties.position == position }) { item in
                        BannerPresentation(banner: item.banner, duration: item.duration)
                    }
                }
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
    }
}
