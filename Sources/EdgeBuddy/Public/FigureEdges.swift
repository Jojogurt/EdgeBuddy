/// Edges of an anchor (`figureAnchor(_:edges:)`) the figure may come out
/// at. The stage draws an edge among the allowed ones that fit and are on
/// screen, evenly: 25% each (renormalized over
/// the edges that are possible right now).
public struct FigureEdges: OptionSet, Hashable, Sendable {
    /// The raw bit mask.
    public let rawValue: Int

    /// Creates a set from a raw bit mask.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Stands on the top edge, the rest of it hidden behind the view.
    public static let top = FigureEdges(rawValue: 1 << 0)
    /// Hangs under the bottom edge: swings, pulls itself up.
    public static let bottom = FigureEdges(rawValue: 1 << 1)
    /// Peeks, flags or climbs at the leading edge.
    public static let leading = FigureEdges(rawValue: 1 << 2)
    /// Peeks, flags or climbs at the trailing edge.
    public static let trailing = FigureEdges(rawValue: 1 << 3)
    /// All four edges.
    public static let all: FigureEdges = [.top, .bottom, .leading, .trailing]
}
