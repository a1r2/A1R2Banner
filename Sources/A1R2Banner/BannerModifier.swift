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

// Position-driven padding + transition. Ported from the app's `BannerModifier`,
// switching on `BannerPosition` instead of the app's banner enum. The app's
// bottom-leading banner used fixed 20-pt insets on both platforms (the geometry
// top/trailing special-case for it was dead code), so bottom-leading keeps the
// fixed padding here too.
extension View {
    #if os(iOS)
    @ViewBuilder
    func applyBannerModifier(position: BannerPosition, showFrom: Edge, geometry: GeometryProxy) -> some View {
        switch position {
        case .topTrailing:
            self.bannerTopTrailingPadding(geometry: geometry).transition(.move(edge: showFrom))
        case .bottomLeading:
            self.bannerBottomLeadingPadding().transition(.move(edge: showFrom))
        case .topLeading:
            self.bannerTopLeadingPadding(geometry: geometry).transition(.move(edge: showFrom))
        case .bottomTrailing:
            self.bannerBottomTrailingPadding(geometry: geometry).transition(.move(edge: showFrom))
        case .bottomCenter:
            self.bannerBottomCenteredPadding().transition(.move(edge: showFrom))
        case .topCenter:
            self.bannerTopCenteredPadding().transition(.move(edge: showFrom))
        }
    }
    #endif

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
        case .topCenter:
            self.bannerTopCenteredPadding().transition(.move(edge: showFrom))
        }
    }

    // MARK: - Fixed (tvOS / bottom-leading / bottom-center)

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

    // Top inset clears the iPhone status bar / Dynamic Island so the banner reads
    // as an extension of it. Tune per device feel if needed.
    func bannerTopCenteredPadding() -> some View {
        padding(EdgeInsets(top: 60, leading: 0, bottom: 0, trailing: 0))
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - iOS geometry-aware padding

    #if os(iOS)
    func bannerTopTrailingPadding(geometry: GeometryProxy) -> some View {
        self.padding(EdgeInsets(
            top: bannerTopPadding(for: geometry),
            leading: 0,
            bottom: 0,
            trailing: bannerTrailingPadding(for: geometry)
        ))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    func bannerBottomTrailingPadding(geometry: GeometryProxy) -> some View {
        self.padding(EdgeInsets(
            top: 0,
            leading: 0,
            bottom: bannerBottomPadding(for: geometry),
            trailing: bannerTrailingPadding(for: geometry)
        ))
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    func bannerTopLeadingPadding(geometry: GeometryProxy) -> some View {
        self.padding(EdgeInsets(
            top: bannerTopPadding(for: geometry),
            leading: bannerLeadingPadding(for: geometry),
            bottom: 0,
            trailing: 0
        ))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // Convert visual padding to actual padding, compensating for the scaleEffect:
    // iPad: ×2 (0.5 scale); iPhone: ×2.5 (0.4 scale).
    private func visualPadding(_ points: CGFloat) -> CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        return isPad ? points * 2 : points * 2.5
    }

    private func bannerTopPadding(for geometry: GeometryProxy) -> CGFloat {
        let screenBounds = UIScreen.main.bounds
        let geometryWidth = geometry.size.width > 0 ? geometry.size.width : screenBounds.width
        let geometryHeight = geometry.size.height > 0 ? geometry.size.height : screenBounds.height

        let isPortrait = geometryHeight > geometryWidth
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        if isPortrait {
            return isPad ? visualPadding(380) : visualPadding(370)
        } else {
            return isPad ? visualPadding(90) : visualPadding(20)
        }
    }

    private func bannerTrailingPadding(for geometry: GeometryProxy) -> CGFloat {
        let isPortrait = geometry.size.height > geometry.size.width
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        if isPad {
            return visualPadding(20)
        } else {
            return isPortrait ? visualPadding(10) : visualPadding(40)
        }
    }

    private func bannerLeadingPadding(for geometry: GeometryProxy) -> CGFloat {
        let isPortrait = geometry.size.height > geometry.size.width
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        if isPad {
            return visualPadding(20)
        } else {
            return isPortrait ? visualPadding(10) : visualPadding(40)
        }
    }

    private func bannerBottomPadding(for geometry: GeometryProxy) -> CGFloat {
        let isPortrait = geometry.size.height > geometry.size.width
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        if isPad {
            return 20
        } else {
            return isPortrait ? 40 : 20
        }
    }
    #endif
}
