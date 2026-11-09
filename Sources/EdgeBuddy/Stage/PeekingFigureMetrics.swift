import SwiftUI

/// Sizes of the figure at one height (`figureHeight(_:)`); everything else
/// scales from it.
struct PeekingFigureMetrics: Equatable, Sendable {
    /// The default height (pt).
    static let defaultHeight: CGFloat = 56
    /// The smallest height a stage draws (pt).
    static let minimumHeight: CGFloat = 16
    /// The figure at the default height.
    static let standard = PeekingFigureMetrics()

    /// Height of the figure's box above the card's edge (pt) — the head with
    /// room for jumps, down to the feet on the edge (`FigureSkeleton.peekBox`).
    let height: CGFloat
    /// The character's boxes at each edge, in its own units.
    let geometry: FigureGeometry

    init(height: CGFloat = PeekingFigureMetrics.defaultHeight, geometry: FigureGeometry = .human) {
        self.height = Self.clampedHeight(height)
        self.geometry = geometry
    }

    /// `height` raised to the minimum; a non-finite value falls back to the default.
    static func clampedHeight(_ height: CGFloat) -> CGFloat {
        height.isFinite ? max(height, minimumHeight) : defaultHeight
    }

    /// Width of the widest box the figure stands on or hangs under (the
    /// top's `FigureSkeleton.peekBox` for the human) at `height`.
    var width: CGFloat {
        let edges = geometry.supportedEdges
        let widths = [
            edges.contains(.top) ? geometry.top.rect.width : nil,
            edges.contains(.bottom) ? geometry.bottom.rect.width : nil,
        ].compactMap { $0 }
        return (height * (widths.max() ?? geometry.top.rect.width) / geometry.referenceHeight).rounded()
    }
    /// Smallest gap from either card edge to the figure's box (28 pt at the
    /// default height).
    var edgeMargin: CGFloat { 28 * height / Self.defaultHeight }
    /// The narrowest anchor the figure stands on.
    var minimumAnchorWidth: CGFloat {
        FigureAnchorPicker.minimumWidth(figureWidth: width, margin: edgeMargin)
    }
    /// Points per grid unit of the rig.
    var scale: CGFloat { height / geometry.referenceHeight }

    /// What the hanging figure draws under a bottom edge: from the edge (its
    /// top) down past the feet, the full width.
    static let hangBox = CGRect(x: 0, y: FigureEdgePoses.bottomEdgeY, width: 100, height: 94)
    /// What a side figure draws: beside the card, outside its side edge
    /// (drawn at the trailing edge, leading = mirrored), from just inside the
    /// edge (`FigureEdgePoses.sideMaskX`, the gripping hands) out to grid x
    /// 200 (the flag's feet), tall enough for the peek, flag and climb.
    static let sideBox = CGRect(
        x: FigureEdgePoses.sideMaskX, y: 0, width: 2 * FigureEdgePoses.sideEdgeX - FigureEdgePoses.sideMaskX, height: 112
    )
    /// How far the side box at `edge` reaches over the card, past its edge, points.
    func sideOverlap(at edge: FigureEdge) -> CGFloat {
        let box = geometry.box(edge)
        return (box.edge - box.rect.minX) * scale
    }
    /// How far the box at `edge` reaches past the card's edge into the card
    /// (top: below the edge, bottom: above it), points — zero for the human.
    func edgeOverlap(at edge: FigureEdge) -> CGFloat {
        let box = geometry.box(edge)
        switch edge {
        case .top: return (box.rect.maxY - box.edge) * scale
        case .bottom: return (box.edge - box.rect.minY) * scale
        case .leading, .trailing: return sideOverlap(at: edge)
        }
    }
    /// Smallest gap from a side box to the visible ends of the card's edge
    /// (12 pt at the default height).
    var sideMargin: CGFloat { 12 * height / Self.defaultHeight }

    /// The part of the character's space drawn at `edge`.
    func box(for edge: FigureEdge) -> CGRect {
        geometry.box(edge).rect
    }

    /// The part of the human rig's grid drawn at `edge`.
    static func box(for edge: FigureEdge) -> CGRect {
        switch edge {
        case .top: FigureSkeleton.peekBox
        case .bottom: hangBox
        case .leading, .trailing: sideBox
        }
    }

    /// Size of the drawn box at `edge`, points.
    func size(for edge: FigureEdge) -> CGSize {
        let box = box(for: edge)
        return CGSize(width: (box.width * scale).rounded(), height: (box.height * scale).rounded())
    }

    /// What an anchor needs at each edge.
    var sizes: FigureSizes {
        let side = max(size(for: .trailing).height, size(for: .leading).height) + 2 * sideMargin
        let top = geometry.top
        let above = top.edge - top.rect.minY
        return FigureSizes(
            figureHeight: above == geometry.referenceHeight ? height : above * scale,
            minWidth: minimumAnchorWidth,
            hangHeight: size(for: .bottom).height - edgeOverlap(at: .bottom),
            sideMinHeight: side,
            // A side at the screen's edge plays only what fits there (the
            // human only climbs): its shortest travel on top of the box.
            climbMinHeight: (side + (geometry.screenEdgeSideRoom ?? .infinity) * scale).rounded(.up),
            screenEdgeGap: screenEdgeGap
        )
    }

    /// How far a side figure may reach past a pager's bounds: its side box.
    /// Those bounds leave out the pager's content margins (they end at the
    /// card), so without it the figure is cut at the card's edge.
    var pagerBleed: CGFloat {
        max(size(for: .trailing).width, size(for: .leading).width)
    }

    /// A side closer than this to the screen's edge only climbs (28 pt at
    /// the default height: wider than the usual 16 pt gutter).
    var screenEdgeGap: CGFloat { 28 * height / Self.defaultHeight }

    /// Points the box moves along `edge` of `rect` between the spots 0 and
    /// 1 (`FigurePlacement`): the free width (top, bottom) or height (sides).
    func travelSpan(at edge: FigureEdge, on rect: CGRect) -> CGFloat {
        let size = size(for: edge)
        return edge.isSide
            ? max(0, rect.height - 2 * sideMargin - size.height)
            : max(0, rect.width - 2 * edgeMargin - size.width)
    }

    /// Spots along a side whose box is on screen in `viewport` (the card may
    /// reach past it); the whole edge for top and bottom.
    func spotRange(at edge: FigureEdge, on rect: CGRect, viewport: CGRect?) -> ClosedRange<Double> {
        guard edge.isSide, let viewport else { return 0...1 }
        let free = travelSpan(at: edge, on: rect)
        guard free > 0 else { return 0...1 }
        let height = size(for: edge).height
        let track = FigureAnchorPicker.sideTrack(rect: rect, viewport: viewport)
        let low = (track.lowerBound - rect.minY) / free
        let high = (track.upperBound - sideMargin - height - sideMargin - rect.minY) / free
        let lower = min(max(Double(low), 0), 1)
        return lower...max(lower, min(max(Double(high), 0), 1))
    }

    /// Grid units the figure can travel along `edge` of `rect` — up a side
    /// (its box staying on screen), along the top either way — from `spot`,
    /// or, when nil (it pops up anew and picks its spot), from the best spot:
    /// the lowest on a side, any on the top (at least half the width lies
    /// one way). Zero at the bottom: nothing travels there.
    func travelRoom(at edge: FigureEdge, on rect: CGRect, viewport: CGRect?, from spot: Double?) -> Double {
        let span = Double(travelSpan(at: edge, on: rect) / scale)
        switch edge {
        case .bottom:
            return 0
        case .top:
            guard let spot else { return span / 2 }
            return span * max(spot, 1 - spot)
        case .leading, .trailing:
            let range = spotRange(at: edge, on: rect, viewport: viewport)
            return span * max(0, (spot ?? range.upperBound) - range.lowerBound)
        }
    }

    /// Hidden at accessibility text sizes, where it would cover too much of
    /// the larger text above the card.
    static func isShown(dynamicTypeSize: DynamicTypeSize) -> Bool {
        !dynamicTypeSize.isAccessibilitySize
    }
}
