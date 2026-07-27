// A1R2Banner — Starter example.

import SwiftUI
import A1R2Banner

/// Demonstrates the two ways to use the SDK:
///   1. `GlassBanner` — the batteries-included Liquid Glass banner, one line to fire.
///   2. A custom `BannerPresentable` (`DemoBanner`) — your own content and styling.
///
/// Each manager gets its own `.bannerOverlay(...)`, attached once here on the root.
struct ContentView: View {
    @StateObject private var glass = BannerManager<GlassBanner>()
    @StateObject private var toasts = BannerManager<DemoBanner>()

    var body: some View {
        NavigationStack {
            List {
                Section("Liquid Glass — zero boilerplate") {
                    Button("Saved to Favorites") {
                        glass.enqueue(GlassBanner(
                            title: "Saved to Favorites",
                            subtitle: "Find it under the Favorites tab",
                            systemImage: "star.fill",
                            tint: .yellow))
                    }
                    Button("Something failed") {
                        glass.enqueue(GlassBanner(
                            title: "Upload failed",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .red))
                    }
                }

                Section("Bring your own banner") {
                    Button("Bottom-trailing toast") {
                        toasts.enqueue(.info("Your own content and styling."))
                    }
                    Button("Stack three (bottom, opt-in)") {
                        toasts.enqueue(.info("First"))
                        toasts.enqueue(.info("Second"))
                        toasts.enqueue(.info("Third"))
                    }
                    Button("Clear the pile", role: .destructive) {
                        toasts.clear()
                    }
                }
            }
            .navigationTitle("A1R2Banner")
        }
        // Attach each manager's overlay once, on a root/container view.
        .bannerOverlay(glass)
        .bannerOverlay(toasts)
    }
}

#Preview {
    ContentView()
}
