// A1R2Banner — Starter example.
// A custom banner: conform any Hashable value to `BannerPresentable`. The SDK owns
// the queue/stacking/timing; you own the content and styling.

import SwiftUI
import A1R2Banner

enum DemoBanner: Hashable {
    case info(String)
}

extension DemoBanner: BannerPresentable {
    var bannerProperties: BannerProperties {
        switch self {
        case .info:
            BannerProperties(
                frame: CGSize(width: 360, height: 66),
                duration: 3,
                position: .bottomTrailing,
                cornerRadius: 18,
                fillColor: .blue,
                showFrom: .trailing,
                renderScale: 1,     // laid out natively — no legacy downscale
                stacks: true        // opt into bottom piling (see the "Stack three" button)
            )
        }
    }

    // Returning a concrete view (no AnyView erasure needed).
    func makeContent() -> DemoBannerView {
        DemoBannerView(banner: self)
    }
}

struct DemoBannerView: View {
    let banner: DemoBanner

    var body: some View {
        let props = banner.bannerProperties
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
            Text(text)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(.white)
        .frame(width: props.frame.width, height: props.frame.height)
        .background(props.fillColor.opacity(0.95),
                    in: RoundedRectangle(cornerRadius: props.cornerRadius))
    }

    private var text: String {
        switch banner {
        case .info(let message): message
        }
    }
}
