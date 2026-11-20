import CoreGraphics

/// What the stage (`PeekingFigureView`) may play where and where the figure
/// comes out next: per anchor, the actions it allows
/// (`figureAnchor(_:edges:actions:)`) that the character plays at the edge
/// with the room on screen. Pure over the anchors' frames, so tests drive
/// the same rules as the view.
struct FigureStageRules {
    /// Marked views in the stage's space, in layout order.
    let anchors: [FigureAnchorFrame]
    /// Visible area of the whole stage; nil = unbounded (a single card).
    let viewport: CGRect?
    let character: AnyFigureCharacter
    let metrics: PeekingFigureMetrics

    /// The visible area for `anchor`: its scroll view's, else the stage's.
    func viewport(for anchor: AnyHashable?) -> CGRect? {
        anchor.flatMap { id in anchors.first { $0.id == id }?.viewport } ?? viewport
    }

    /// What it may play at `edge` of `rect` (the anchor `anchor`) starting
    /// at `spot` (nil = it pops up and picks the spot): the anchor's actions
    /// (its list, else the edge's random repertoire without opt-in actions)
    /// with the room to travel there; only the climb at a side by the
    /// screen's edge.
    func actions(at edge: FigureEdge, on rect: CGRect, anchor: AnyHashable?, from spot: Double?) -> [String] {
        let visible = viewport(for: anchor)
        return character.actions(
            at: edge, room: metrics.travelRoom(at: edge, on: rect, viewport: visible, from: spot),
            atScreenEdge: FigureAnchorPicker.isAtScreenEdge(
                rect: rect, edge: edge, viewport: visible, gap: metrics.screenEdgeGap
            ),
            listed: anchor.flatMap { id in anchors.first { $0.id == id } }?.actions
        )
    }

    /// A random anchor and edge among `allowed`, fully on screen: one with
    /// an action to play (an anchor whose list has nothing there only when
    /// none has; not for a play without an action, `resting`), then one with
    /// something other than `previous`, on another anchor than `current` (or
    /// another edge of it) when there is one; nil = none fits.
    func placement(
        excluding current: AnyHashable?, edge currentEdge: FigureEdge?, allowed: FigureEdges,
        after previous: String?, resting: Bool = false, using generator: inout some RandomNumberGenerator
    ) -> (id: AnyHashable, edge: FigureEdge)? {
        FigureAnchorPicker.nextPlacement(
            current: current,
            currentEdge: currentEdge,
            candidates: candidates,
            viewport: viewport,
            viewportFor: { viewport(for: $0) },
            sizes: metrics.sizes,
            allowed: allowed,
            offersAny: resting ? nil : { id, rect, edge in
                !actions(at: edge, on: rect, anchor: id, from: nil).isEmpty
            },
            offersFresh: { id, rect, edge in
                actions(at: edge, on: rect, anchor: id, from: nil).contains { $0 != previous }
            },
            using: &generator
        )
    }

    /// Where a play without an action (the rest) goes, among `allowed`
    /// (`FigureAnchorPicker.restingPlacement`): any anchor, whatever its list.
    func restingPlacement(
        current: AnyHashable?, allowed: FigureEdges, using generator: inout some RandomNumberGenerator
    ) -> (id: AnyHashable, edge: FigureEdge)? {
        FigureAnchorPicker.restingPlacement(
            current: current,
            candidates: candidates,
            viewport: viewport,
            viewportFor: { viewport(for: $0) },
            sizes: metrics.sizes,
            allowed: allowed,
            using: &generator
        )
    }

    private var candidates: [(id: AnyHashable, rect: CGRect, edges: FigureEdges)] {
        anchors.map { (id: $0.id, rect: $0.rect, edges: $0.edges) }
    }
}
