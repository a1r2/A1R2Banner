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

/// The Liquid Glass content for ``GlassBanner``. Public so hosts that keep their
/// own banner type can reuse the look from `makeContent()`.
///
/// It renders a single Liquid Glass capsule (`glassEffect`) that refracts and
/// adapts to whatever sits behind it. When it carries a leading icon, it starts
/// as a compact pill and **expands** to reveal the text with a bouncy reveal;
/// icon-less banners start expanded (no empty-capsule flash). Honors Reduce Motion
/// (no bounce/sheen/haptic) — the SDK's `BannerView` also swaps the slide-in for a
/// fade under Reduce Motion.
public struct GlassBannerContent: View {
    private let banner: GlassBanner

    public init(banner: GlassBanner) {
        self.banner = banner
        // Start expanded when there's no icon, so the first frame is never a bare capsule.
        _expanded = State(initialValue: banner.systemImage == nil)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: Bool
    @State private var sheen = false

    public var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 10) {
                if let symbol = banner.systemImage {
                    Image(systemName: symbol)
                        .font(.headline.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                }

                if expanded {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(banner.title)
                            .font(.subheadline.weight(.semibold))
                        if let subtitle = banner.subtitle {
                            Text(subtitle)
                                .font(.caption)
                        }
                    }
                    .layoutPriority(1)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .foregroundStyle(banner.textColor)
            .padding(.horizontal, expanded ? 18 : 12)
            .padding(.vertical, 12)
            // A dark backing keeps the default white foreground readable over light hosts.
            .background(.black.opacity(0.65), in: .capsule)
            // The signature: real Liquid Glass, tinted, and interactive (flexes to touch).
            .glassEffect(.regular.tint(banner.tint.opacity(0.18)).interactive(), in: .capsule)
            .overlay { sheenOverlay }
        }
        .onAppear(perform: reveal)
    }

    // A soft diagonal highlight that fades as the glass "catches the light" on appear.
    @ViewBuilder
    private var sheenOverlay: some View {
        if !reduceMotion {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.5), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.plusLighter)
                .opacity(sheen ? 0 : 0.9)
                .allowsHitTesting(false)
        }
    }

    private func reveal() {
        guard !reduceMotion else {
            expanded = true
            return
        }
        withAnimation(.bouncy(duration: 0.5)) { expanded = true }
        withAnimation(.easeOut(duration: 1.0)) { sheen = true }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}
