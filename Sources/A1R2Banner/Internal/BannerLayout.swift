import SwiftUI

/// Small, device-independent policy shared by measurement and placement.
enum BannerSizing {
    static func dimension(_ value: CGFloat?, fallback: CGFloat) -> CGFloat {
        guard let value, value.isFinite else { return fallback }
        return max(0, value)
    }

    static func scale(_ value: CGFloat?) -> CGFloat {
        guard let value, value.isFinite, value > 0 else { return 1 }
        return value
    }

    static func limit(_ proposal: ProposedViewSize, maximumWidth: CGFloat) -> CGSize {
        let maximum = dimension(maximumWidth, fallback: 560)
        return CGSize(width: min(dimension(proposal.width, fallback: maximum), maximum),
                      height: dimension(proposal.height, fallback: .greatestFiniteMagnitude))
    }

    static func footprint(_ measured: CGSize, limit: CGSize, scale: CGFloat) -> CGSize {
        CGSize(width: min(dimension(measured.width * scale, fallback: limit.width), limit.width),
               height: min(dimension(measured.height * scale, fallback: limit.height), limit.height))
    }

    static func inset(_ length: CGFloat) -> CGFloat { min(20, length / 10) }
}

/// Measures native content under a finite width proposal. Explicit legacy art
/// scales are opt-in: both the proposal and reported footprint account for them.
struct BannerContentLayout: Layout {
    var maximumWidth: CGFloat
    var scale: CGFloat = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let limit = BannerSizing.limit(proposal, maximumWidth: maximumWidth)
        let measured = content.sizeThatFits(contentProposal(limit))
        return BannerSizing.footprint(measured, limit: limit, scale: scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Use the same bounds we reported, so placement cannot restore an
        // unbounded/fixed-size child's ideal dimensions as the wrapper's footprint.
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: contentProposal(bounds.size))
    }

    private func contentProposal(_ limit: CGSize) -> ProposedViewSize {
        ProposedViewSize(width: BannerSizing.dimension(limit.width / scale, fallback: .greatestFiniteMagnitude),
                         height: limit.height == .greatestFiniteMagnitude ? nil :
                            BannerSizing.dimension(limit.height / scale, fallback: .greatestFiniteMagnitude))
    }
}

/// Positions one banner or an oldest-first bottom pile within the host region.
/// Each next banner receives the remaining height. Actual measured heights drive
/// placement, so wrapping and Dynamic Type do not depend on frame-height guesses.
struct BannerRegionLayout: Layout {
    var position: BannerPosition
    var spacing: CGFloat = 16
    var offset: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let idealWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = BannerSizing.dimension(proposal.width, fallback: idealWidth + 40)
        let innerWidth = max(0, width - 2 * BannerSizing.inset(width))
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: innerWidth, height: nil)).height
        }
        let gap = BannerSizing.dimension(spacing, fallback: 16)
        let idealHeight = heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * gap + 40
        return CGSize(width: width,
                      height: BannerSizing.dimension(proposal.height,
                          fallback: BannerSizing.dimension(idealHeight, fallback: .greatestFiniteMagnitude)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let dx = BannerSizing.inset(bounds.width)
        let dy = BannerSizing.inset(bounds.height)
        let region = bounds.insetBy(dx: dx, dy: dy)
        let reservation = position.isTopAnchored ? offset : -offset
        var used = min(BannerSizing.dimension(reservation, fallback: 0), region.height)
        for view in subviews {
            let available = ProposedViewSize(width: region.width, height: max(0, region.height - used))
            let size = view.sizeThatFits(available)
            let x: CGFloat
            switch position {
            case .topLeading, .bottomLeading: x = region.minX
            case .topTrailing, .bottomTrailing: x = region.maxX - size.width
            case .topCenter, .bottomCenter: x = region.midX - size.width / 2
            }
            let y = position.isTopAnchored ? region.minY + used : region.maxY - used - size.height
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: available)
            used = min(region.height, used + size.height + BannerSizing.dimension(spacing, fallback: 16))
        }
    }
}
