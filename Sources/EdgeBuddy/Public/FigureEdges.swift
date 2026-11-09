import SwiftUI

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
    /// Flags or climbs at the leading edge (the left in left-to-right
    /// layouts, the right in right-to-left ones).
    public static let leading = FigureEdges(rawValue: 1 << 2)
    /// Flags or climbs at the trailing edge.
    public static let trailing = FigureEdges(rawValue: 1 << 3)
    /// All four edges.
    public static let all: FigureEdges = [.top, .bottom, .leading, .trailing]

    /// The same edges as physical sides: in right-to-left layouts leading
    /// is the right and trailing the left (the stage's geometry is physical).
    func physical(for direction: LayoutDirection) -> FigureEdges {
        guard direction == .rightToLeft else { return self }
        var result = subtracting([.leading, .trailing])
        if contains(.leading) { result.insert(.trailing) }
        if contains(.trailing) { result.insert(.leading) }
        return result
    }
}
