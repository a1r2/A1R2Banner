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
/// own banner type can reuse the look from `makeContent()`:
///
/// ```swift
/// func makeContent() -> AnyView {
///     AnyView(GlassBannerContent(banner: GlassBanner(title: "Saved", systemImage: "star.fill")))
/// }
/// ```
///
/// It renders a single Liquid Glass capsule inside a `GlassEffectContainer` that
/// **morphs open from a compact pill** — Dynamic-Island style — then settles. The
/// glass refracts whatever sits behind it and adapts to light/dark automatically.
public struct GlassBannerContent: View {
    private let banner: GlassBanner

    public init(banner: GlassBanner) {
        self.banner = banner
    }

    @Namespace private var glass
    @State private var expanded = false
    @State private var sheen = false

    public var body: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 10) {
                if let symbol = banner.systemImage {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(banner.tint)
                        .frame(width: 30, height: 30)
                        .transition(.scale.combined(with: .opacity))
                }

                if expanded {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(banner.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if let subtitle = banner.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fixedSize()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, expanded ? 18 : 12)
            .padding(.vertical, 12)
            // The signature: real Liquid Glass, tinted, and interactive (flexes to touch).
            .glassEffect(.regular.tint(banner.tint.opacity(0.18)).interactive(), in: .capsule)
            .glassEffectID("core", in: glass)
            .overlay { sheenOverlay }
        }
        // Condense-from-the-Island: start compact and slightly up, then morph open.
        .scaleEffect(expanded ? 1 : 0.82, anchor: .top)
        .onAppear(perform: reveal)
    }

    // A soft diagonal highlight that fades as the glass "catches the light" on appear.
    private var sheenOverlay: some View {
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

    private func reveal() {
        withAnimation(.bouncy(duration: 0.5)) { expanded = true }
        withAnimation(.easeOut(duration: 1.0)) { sheen = true }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}
