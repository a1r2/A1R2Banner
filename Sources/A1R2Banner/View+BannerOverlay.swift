// Copyright © 2026 Adriano Rossi Ramos / A1R2
//
// This file was created under the direction and creative control of the
// copyright holder, with assistance from AI tools (Claude/Prometheus/OpenClaw).
// Architectural decisions, requirements, and design are solely the work
// of the human author.
//
// All rights reserved.


import SwiftUI

public extension View {
    /// Overlays the banner stack driven by `manager` on top of this view.
    /// Attach once on a root/container view.
    func bannerOverlay<Banner: BannerPresentable>(_ manager: BannerManager<Banner>) -> some View {
        overlay { BannerOverlayView(manager: manager) }
    }
}
