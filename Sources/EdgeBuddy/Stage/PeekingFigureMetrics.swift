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

    init(height: CGFloat = PeekingFigureMetrics.defaultHeight) {
        self.height = max(height, Self.minimumHeight)
    }

    /// Width of `FigureSkeleton.peekBox` at `height`.
    var width: CGFloat {
        (height * FigureSkeleton.peekBox.width / FigureSkeleton.peekBox.height).rounded()
    }
    /// Smallest gap from either card edge to the figure's box (28 pt at the
    /// default height).
    var edgeMargin: CGFloat { 28 * height / Self.defaultHeight }
    /// The narrowest anchor the figure stands on.
    var minimumAnchorWidth: CGFloat {
        FigureAnchorPicker.minimumWidth(figureWidth: width, margin: edgeMargin)
    }
    /// Points per grid unit of the rig.
    var scale: CGFloat { height / FigureSkeleton.peekBox.height }

    /// What the hanging figure draws under a bottom edge: from the edge (its
    /// top) down past the feet, the full width.
    static let hangBox = CGRect(x: 0, y: FigureEdgePoses.bottomEdgeY, width: 100, height: 94)
    /// What a side figure draws: the card's side edge is the box's trailing
    /// edge (leading = mirrored), tall enough for the peek, flag and climb.
    static let sideBox = CGRect(x: 0, y: 0, width: FigureEdgePoses.sideEdgeX, height: 112)
    /// Smallest gap from a side box to the visible ends of the card's edge
    /// (12 pt at the default height).
    var sideMargin: CGFloat { 12 * height / Self.defaultHeight }

    /// The part of the rig's grid drawn at `edge`.
    static func box(for edge: FigureEdge) -> CGRect {
        switch edge {
        case .top: FigureSkeleton.peekBox
        case .bottom: hangBox
        case .leading, .trailing: sideBox
        }
    }

    /// Size of the drawn box at `edge`, points.
    func size(for edge: FigureEdge) -> CGSize {
        let box = Self.box(for: edge)
        return CGSize(width: (box.width * scale).rounded(), height: (box.height * scale).rounded())
    }

    /// What an anchor needs at each edge.
    var sizes: FigureSizes {
        FigureSizes(
            figureHeight: height, minWidth: minimumAnchorWidth,
            hangHeight: size(for: .bottom).height,
            sideMinHeight: size(for: .trailing).height + 2 * sideMargin
        )
    }

    /// Hidden at accessibility text sizes, where it would cover too much of
    /// the larger text above the card.
    static func isShown(dynamicTypeSize: DynamicTypeSize) -> Bool {
        !dynamicTypeSize.isAccessibilitySize
    }
}
