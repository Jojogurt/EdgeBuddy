import SwiftUI

/// A pose a pinned figure (`FigurePin`) plays and then holds still in — the
/// actions that have a clear still frame. Each belongs to an edge; pinned at
/// another edge, the figure rests there instead.
public enum FigurePose: CaseIterable, Hashable, Sendable {
    /// Standing with hands on hips (top), hanging (bottom), peeking from
    /// behind the edge (sides) — every edge.
    case rest
    /// Top: one arm up in a greeting.
    case wave
    /// Top: arms and legs spread wide.
    case jumpingJacks
    /// Top: arms up, bent to one side.
    case sideStretch
    /// Top: a knee up, the opposite fist pumped.
    case march
    /// Top: balanced on its hands, legs up.
    case handstand
    /// Bottom: swung out to one side, hanging by its hands.
    case swing
    /// Bottom: pulled up, the head at the edge.
    case pullUp
    /// Sides: hanging out beside the card, a hand on its edge.
    case peek
    /// Sides: a human flag — the body held out flat beside the card.
    case flag

    /// The edges this pose is played at.
    public var edges: FigureEdges {
        switch self {
        case .rest: .all
        case .wave, .jumpingJacks, .sideStretch, .march, .handstand: .top
        case .swing, .pullUp: .bottom
        case .peek, .flag: [.leading, .trailing]
        }
    }

    /// The rig's action for this pose at `edge`: the pose where it is played,
    /// else the edge's rest.
    func action(at edge: FigureEdge) -> FigureAction {
        guard edges.contains(edge.member) else { return .rest }
        return switch self {
        case .rest: .rest
        case .wave: .wave
        case .jumpingJacks: .jumpingJacks
        case .sideStretch: .sideStretch
        case .march: .march
        case .handstand: .handstand
        case .swing: .swing
        case .pullUp: .pullUp
        case .peek: .peek
        case .flag: .flag
        }
    }
}

/// Pins a stage's figure to one anchor, edge and pose — a deterministic,
/// still figure for screenshots, previews and snapshot tests
/// (`figurePinned(_:)`).
///
/// With a pin the stage skips the entrance delay and every random pick: the
/// figure comes out at `edge` of the anchor `anchor` (whatever edges that
/// anchor allows), plays `pose` and freezes at its hold frame. It never
/// loops, ignores taps, and holds the frame also under Reduce Motion, in Low
/// Power Mode and with idle motion off. When the anchor is not on screen or
/// the figure does not fit at that edge, the stage behaves as without a pin
/// (and takes the pin up as soon as it fits).
// Sendable: `anchor` only ever wraps a `Sendable` id (see `init`).
public struct FigurePin: Hashable, @unchecked Sendable {
    /// The anchor's id, as passed to `figureAnchor(_:edges:)`.
    public let anchor: AnyHashable
    /// The edge the figure comes out at.
    public let edge: FigureEdges
    /// What it plays and holds.
    public let pose: FigurePose
    /// Where along the edge, 0…1: left to right on the top and the bottom,
    /// top to bottom at the sides.
    public let spot: Double
    /// true = it comes out and plays up to the hold frame (unless Reduce
    /// Motion is on); false = it shows the hold frame at once.
    public let animated: Bool

    /// A pin at `edge` of the anchor `anchor`, holding `pose`.
    ///
    /// - Parameters:
    ///   - anchor: the id of a view marked with `figureAnchor(_:edges:)`
    ///     under the stage; for `peekingFigure` use `singleCard(edge:pose:spot:animated:)`.
    ///   - edge: a single edge (of several, the first of top, bottom,
    ///     leading, trailing is used; an empty set means top).
    ///   - pose: what it plays and holds; a pose of another edge rests.
    ///   - spot: where along the edge, 0…1, clamped to the part on screen;
    ///     0.5 (the middle) by default.
    ///   - animated: false = the hold frame at once, no entrance — the
    ///     steadiest choice for snapshots. True by default.
    public init(
        anchor: some Hashable & Sendable, edge: FigureEdges = .top, pose: FigurePose,
        spot: Double = 0.5, animated: Bool = true
    ) {
        self.anchor = AnyHashable(anchor)
        self.edge = edge
        self.pose = pose
        self.spot = min(max(spot, 0), 1)
        self.animated = animated
    }

    private init(anchor: AnyHashable, edge: FigureEdges, pose: FigurePose, spot: Double, animated: Bool) {
        self.anchor = anchor
        self.edge = edge
        self.pose = pose
        self.spot = spot
        self.animated = animated
    }

    /// The pin with its edge as a physical side (`FigureEdges.physical(for:)`).
    func physical(for direction: LayoutDirection) -> FigurePin {
        FigurePin(anchor: anchor, edge: edge.physical(for: direction), pose: pose, spot: spot, animated: animated)
    }

    /// A pin for the figure of a single card (`peekingFigure`), whose only
    /// anchor has no id of yours. Set it on that card or above it.
    ///
    /// - Parameters: as `init(anchor:edge:pose:spot:animated:)`.
    public static func singleCard(
        edge: FigureEdges = .top, pose: FigurePose, spot: Double = 0.5, animated: Bool = true
    ) -> FigurePin {
        FigurePin(anchor: SoloAnchor.id, edge: edge, pose: pose, spot: spot, animated: animated)
    }

    /// The single rig edge for `edge`.
    var figureEdge: FigureEdge {
        FigureEdge.allCases.first { edge.contains($0.member) } ?? .top
    }
}

extension EnvironmentValues {
    /// The stage's pinned figure (`figurePinned(_:)`); nil = it plays freely.
    @Entry var figurePin: FigurePin?
}

extension View {
    /// Pins every stage's figure in this view hierarchy to one anchor, edge
    /// and pose — a deterministic, still frame for App Store screenshots,
    /// previews and snapshot tests. Pass nil to let it play freely again.
    ///
    /// ```swift
    /// ScrollView { … }
    ///     .figureStage()
    ///     .figurePinned(FigurePin(anchor: "hero", edge: .trailing, pose: .flag))
    /// ```
    ///
    /// See `FigurePin` for what a pin skips and when it falls back.
    ///
    /// - Parameter pin: where and how the figure holds still; nil = no pin.
    public func figurePinned(_ pin: FigurePin?) -> some View {
        environment(\.figurePin, pin)
    }
}

/// A pinned figure resolved against the stage's anchors: where it stands and
/// what it plays — no randomness.
struct FigurePinnedPlay: Equatable {
    let anchor: AnyHashable
    let edge: FigureEdge
    /// Spot along the edge (`FigurePlacement`), within the part on screen.
    let spot: Double
    let action: FigureAction
    let timeline: FigureTimeline
    /// Seconds from the start where it freezes.
    let holdTime: Double

    /// The pin's anchor and edge when that anchor is among `anchors` and the
    /// figure fits there and shows whole (`FigureAnchorPicker.isEligible`);
    /// nil = fall back to the free stage.
    static func resolve(
        _ pin: FigurePin, anchors: [FigureAnchorFrame], viewport: CGRect?,
        metrics: PeekingFigureMetrics, style: FigureStyle
    ) -> FigurePinnedPlay? {
        let edge = pin.figureEdge
        guard let frame = anchors.first(where: { $0.id == pin.anchor }),
              FigureAnchorPicker.isEligible(rect: frame.rect, edge: edge, viewport: viewport, sizes: metrics.sizes)
        else { return nil }
        let range = metrics.spotRange(at: edge, on: frame.rect, viewport: viewport)
        let action = pin.pose.action(at: edge)
        let timeline = FigureTimeline(
            action: action, entrance: pin.animated ? style.entrance : nil, reduceMotion: false,
            edge: edge, tempo: style.tempo
        )
        return FigurePinnedPlay(
            anchor: frame.id, edge: edge,
            spot: min(max(pin.spot, range.lowerBound), range.upperBound),
            action: action, timeline: timeline,
            holdTime: timeline.holdTime ?? timeline.duration
        )
    }
}
