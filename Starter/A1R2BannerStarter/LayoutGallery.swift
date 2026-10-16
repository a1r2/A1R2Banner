import SwiftUI
import A1R2Banner

/// Launch Starter with --layout-review for a stable compositor/screenshot fixture.
/// Widths describe containers, not devices. The same fixture runs on iOS and tvOS.
struct LayoutGallery: View {
    private var scheme: ColorScheme { ProcessInfo.processInfo.arguments.contains("--light") ? .light : .dark }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Host-constrained banner review").font(.title2)
                GlassBannerContent(banner: GlassBanner(
                    title: "White foreground", subtitle: "Text and symbol share one style",
                    systemImage: "star.fill", tint: .blue))
                    .frame(maxWidth: 360)
                GlassBannerContent(banner: GlassBanner(
                    title: "Orange override", subtitle: "Explicit color stays configurable",
                    systemImage: "star.fill", tint: .black, textColor: .orange))
                    .frame(maxWidth: 360)
                ForEach([120, 240, 360, 560], id: \.self) { width in
                    VStack(spacing: 4) {
                        Text("Container width: \(width) pt").font(.caption)
                        ScrollView(.horizontal) {
                            Color.blue.opacity(0.12)
                                .frame(width: CGFloat(width), height: 160)
                                .overlay {
                                    BannerView(banner: GlassBanner(
                                        title: "Long content wraps inside the available region",
                                        subtitle: "Resize the container; no scale calculation is needed.",
                                        duration: .infinity))
                                }
                        }
                        .frame(height: 160)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.primary)
        .background(scheme == .light ? Color.white : Color.black)
        .preferredColorScheme(scheme)
    }
}
