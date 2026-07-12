// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The stack of currently-queued banners, oldest first. Drives its layout from
/// the manager. On iOS the stacking offset is scaled to match `BannerView`'s
/// `scaleEffect` (0.5 iPad / 0.4 iPhone).
struct BannerOverlayView<Banner: BannerPresentable>: View {
    @ObservedObject var manager: BannerManager<Banner>

    var body: some View {
        #if os(iOS)
        GeometryReader { geometry in
            bannersStack(geometry: geometry)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .edgesIgnoringSafeArea(.all)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        bannersStack(geometry: nil)
        #endif
    }

    #if os(iOS)
    private var bannerScaleFactor: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 0.5 : 0.4
    }
    #endif

    @ViewBuilder
    private func bannersStack(geometry: GeometryProxy?) -> some View {
        ForEach(manager.items.sorted { $0.when < $1.when }) { item in
            #if os(iOS)
            if let geometry = geometry {
                BannerView(banner: item.banner, geometry: geometry)
                    .offset(y: item.offset * bannerScaleFactor)
            }
            #else
            BannerView(banner: item.banner)
                .offset(y: item.offset)
            #endif
        }
    }
}
