// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

/// The stack of currently-queued banners, oldest first. Each `BannerView` fills
/// the overlay and pins itself to its own corner (safe-area aware), so the
/// container tracks any size — rotation, split view, or a resized macOS window.
struct BannerOverlayView<Banner: BannerPresentable>: View {
    @ObservedObject var manager: BannerManager<Banner>

    var body: some View {
        ZStack {
            ForEach(manager.items.sorted { $0.when < $1.when }) { item in
                BannerView(banner: item.banner, duration: item.duration, stackOffset: item.offset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
