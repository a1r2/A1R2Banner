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

struct BannerPositionKey: LayoutValueKey {
    static let defaultValue: BannerPosition = .topLeading
}
struct BannerStacksKey: LayoutValueKey {
    static let defaultValue = false
}

/// Measured placement only. Subviews remain in enqueue order for drawing, while
/// each bottom position accumulates its own actual content heights.
struct BannerRegionLayout: Layout {
    var position: BannerPosition? = nil
    var spacing: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let idealWidth = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = BannerSizing.dimension(proposal.width, fallback: idealWidth + 40)
        let innerWidth = max(0, width - 2 * BannerSizing.inset(width))
        var used: [BannerPosition: CGFloat] = [:]
        var height: CGFloat = 0
        for view in subviews {
            let anchor = position ?? view[BannerPositionKey.self]
            let measured = view.sizeThatFits(ProposedViewSize(width: innerWidth, height: nil)).height
            if view[BannerStacksKey.self] && !anchor.isTopAnchored {
                let previous = used[anchor, default: 0]
                height = max(height, previous + measured)
                used[anchor] = previous + measured + gap
            } else {
                height = max(height, measured)
            }
        }
        return CGSize(width: width, height: BannerSizing.dimension(proposal.height, fallback: height + 40))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let region = bounds.insetBy(dx: BannerSizing.inset(bounds.width), dy: BannerSizing.inset(bounds.height))
        var used: [BannerPosition: CGFloat] = [:]
        for view in subviews {
            let anchor = position ?? view[BannerPositionKey.self]
            let stacks = view[BannerStacksKey.self] && !anchor.isTopAnchored
            let consumed = stacks ? used[anchor, default: 0] : 0
            let available = ProposedViewSize(width: region.width, height: max(0, region.height - consumed))
            let size = view.sizeThatFits(available)
            let x: CGFloat
            switch anchor {
            case .topLeading, .bottomLeading: x = region.minX
            case .topTrailing, .bottomTrailing: x = region.maxX - size.width
            case .topCenter, .bottomCenter: x = region.midX - size.width / 2
            }
            let y = anchor.isTopAnchored ? region.minY : region.maxY - consumed - size.height
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: available)
            if stacks { used[anchor] = min(region.height, consumed + size.height + gap) }
        }
    }

    private var gap: CGFloat { BannerSizing.dimension(spacing, fallback: 16) }
}

/// Drawing and interaction move together; this transform never changes the
/// measured footprint. The historical move envelope includes 20 pt per side.
struct BannerMotion: AnimatableModifier {
    var progress: CGFloat
    var edge: Edge
    var direction: LayoutDirection
    var offset: CGFloat
    var reduceMotion: Bool
    var isDrawing = true

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, offset) }
        set { progress = newValue.first; offset = newValue.second }
    }

    func body(content: Content) -> some View {
        content
            .modifier(BannerTranslation(progress: reduceMotion ? 0 : progress,
                                        edge: edge, direction: direction, offset: offset))
            .opacity(isDrawing ? (reduceMotion ? 1 - progress : 1) : 0)
            .allowsHitTesting(isDrawing)
            .anchorPreference(key: BannerHitAnchors.self, value: .bounds) {
                isDrawing ? [BannerHitAnchor(bounds: $0, movement: BannerTranslation(
                    progress: reduceMotion ? 0 : progress, edge: edge, direction: direction, offset: offset))] : []
            }
            .transaction { $0.animation = nil }
    }
}

struct BannerTranslation: GeometryEffect {
    var progress: CGFloat
    var edge: Edge
    var direction: LayoutDirection
    var offset: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let delta = translation(size: size)
        return ProjectionTransform(CGAffineTransform(translationX: delta.width, y: delta.height))
    }

    func translation(size: CGSize) -> CGSize {
        let horizontal: CGFloat = edge == .leading ? -(size.width + 40) : edge == .trailing ? size.width + 40 : 0
        let dx = horizontal * (direction == .leftToRight ? 1 : -1) * progress
        let dy = (edge == .top ? -(size.height + 40) : edge == .bottom ? size.height + 40 : 0) * progress
        return CGSize(width: dx, height: dy + offset)
    }
}

struct BannerHitAnchor {
    var bounds: Anchor<CGRect>
    var movement: BannerTranslation
}
struct BannerHitAnchors: PreferenceKey {
    static let defaultValue: [BannerHitAnchor] = []
    static func reduce(value: inout [BannerHitAnchor], nextValue: () -> [BannerHitAnchor]) {
        value += nextValue()
    }
}
private struct BannerHitRects: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

/// Resolves moving content anchors inside the host. Geometry is read only for
/// interaction: these rectangles never participate in measurement or placement.
struct BannerHostHits: ViewModifier {
    @State private var rects: [CGRect] = []
    func body(content: Content) -> some View {
        content
            .backgroundPreferenceValue(BannerHitAnchors.self) { anchors in
                GeometryReader { geometry in
                    Color.clear.preference(key: BannerHitRects.self, value: anchors.compactMap {
                        let rest = geometry[$0.bounds]
                        let delta = $0.movement.translation(size: rest.size)
                        let rect = rest.offsetBy(dx: delta.width, dy: delta.height)
                            .intersection(CGRect(origin: .zero, size: geometry.size))
                        return rect.isNull || rect.isEmpty ? nil : rect
                    })
                }.allowsHitTesting(false)
            }
            .onPreferenceChange(BannerHitRects.self) { rects = $0 }
            .contentShape(BannerHitShape(rects: rects))
            .allowsHitTesting(!rects.isEmpty)
    }
}

private struct BannerHitShape: Shape {
    var rects: [CGRect]
    func path(in bounds: CGRect) -> Path {
        Path { path in for rect in rects { path.addRect(rect) } }
    }
}
