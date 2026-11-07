import SwiftUI

/// The part of a character's coordinate space drawn at one edge, and where
/// the card's edge runs through it.
struct FigureCharacterBox: Equatable, Sendable {
    /// The drawn rectangle, the character's units, y down. Nothing outside
    /// it shows; it is also the tap area.
    var rect: CGRect
    /// The card's edge in the same units: a y for the top and the bottom,
    /// an x for the sides (drawn as the trailing side, the card to the left).
    var edge: CGFloat

    init(_ rect: CGRect, edge: CGFloat) {
        self.rect = rect
        self.edge = edge
    }
}

/// A character's footprint at every edge — what layout, hit testing and the
/// anchor picker need (`PeekingFigureMetrics`).
struct FigureGeometry: Equatable, Sendable {
    var top: FigureCharacterBox
    var bottom: FigureCharacterBox
    var leading: FigureCharacterBox
    var trailing: FigureCharacterBox
    /// The character's units `figureHeight(_:)` spans in points.
    var referenceHeight: CGFloat
    /// The edges the character plays at.
    var supportedEdges: FigureEdges
    /// The least room along a side a side action that plays at the screen's
    /// edge needs, the character's units; nil = none plays there.
    var screenEdgeSideRoom: Double?

    func box(_ edge: FigureEdge) -> FigureCharacterBox {
        switch edge {
        case .top: top
        case .bottom: bottom
        case .leading: leading
        case .trailing: trailing
        }
    }

    /// The human rig's footprint (`FigureSkeleton.peekBox`,
    /// `PeekingFigureMetrics.hangBox`, `.sideBox`).
    static let human = FigureGeometry(
        top: FigureCharacterBox(FigureSkeleton.peekBox, edge: FigureSkeleton.edgeY),
        bottom: FigureCharacterBox(PeekingFigureMetrics.hangBox, edge: FigureEdgePoses.bottomEdgeY),
        leading: FigureCharacterBox(PeekingFigureMetrics.sideBox, edge: FigureEdgePoses.sideEdgeX),
        trailing: FigureCharacterBox(PeekingFigureMetrics.sideBox, edge: FigureEdgePoses.sideEdgeX),
        referenceHeight: FigureSkeleton.peekBox.height,
        supportedEdges: .all,
        screenEdgeSideRoom: FigureRepertoire.screenEdgeSide.compactMap(FigureTimeline.minimumTravel).min()
    )
}

/// A character with its pose type erased, as the stage keeps it: closures
/// over the concrete character. Built once per body evaluation of the stage;
/// per frame only `frame(_:at:edge:heading:)` runs (one pose, one drawing
/// closure).
struct AnyFigureCharacter: Sendable {
    /// The character's type: another type starts the stage over (a play of
    /// one type can't be drawn by another).
    let typeID: ObjectIdentifier
    let geometry: FigureGeometry
    private let actionsAt: @Sendable (_ edge: FigureEdge, _ room: Double, _ atScreenEdge: Bool) -> [String]
    private let infoFor: @Sendable (_ action: String, _ edge: FigureEdge) -> FigureActionInfo
    private let pinnedAt: @Sendable (_ action: String, _ edge: FigureEdge) -> String
    private let makePlay: @Sendable (FigurePlayRequest) -> FigurePlay
    private let frameAt: @Sendable (_ play: FigurePlay, _ time: Double, _ edge: FigureEdge, _ heading: Double) -> FigureFrame?

    init(
        typeID: ObjectIdentifier, geometry: FigureGeometry,
        actions: @escaping @Sendable (FigureEdge, Double, Bool) -> [String],
        info: @escaping @Sendable (String, FigureEdge) -> FigureActionInfo,
        pinned: @escaping @Sendable (String, FigureEdge) -> String,
        play: @escaping @Sendable (FigurePlayRequest) -> FigurePlay,
        frame: @escaping @Sendable (FigurePlay, Double, FigureEdge, Double) -> FigureFrame?
    ) {
        self.typeID = typeID
        self.geometry = geometry
        self.actionsAt = actions
        self.infoFor = info
        self.pinnedAt = pinned
        self.makePlay = play
        self.frameAt = frame
    }

    /// What it may play at `edge` with `room` units to travel along it; a
    /// side `atScreenEdge` has no room beside the card. Empty = nothing
    /// (the stage then only rests there).
    func actions(at edge: FigureEdge, room: Double, atScreenEdge: Bool) -> [String] {
        actionsAt(edge, room, atScreenEdge)
    }

    func info(_ action: String, at edge: FigureEdge) -> FigureActionInfo {
        infoFor(action, edge)
    }

    /// The action a pin naming `action` plays at `edge`: that action where
    /// the character plays it there, else the rest.
    func pinnedAction(_ action: String, at edge: FigureEdge) -> String {
        pinnedAt(action, edge)
    }

    func play(_ request: FigurePlayRequest) -> FigurePlay {
        makePlay(request)
    }

    /// The frame of `play` at `time` at `edge`; `heading` < 0 while the
    /// figure moves (or will move) toward smaller spots, > 0 the other way.
    /// nil when the play belongs to another character type.
    func frame(_ play: FigurePlay, at time: Double, edge: FigureEdge, heading: Double) -> FigureFrame? {
        frameAt(play, time, edge, heading)
    }
}
