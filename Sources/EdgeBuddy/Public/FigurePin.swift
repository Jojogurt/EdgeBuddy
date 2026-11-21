import SwiftUI

/// A pose of ``HumanFigure`` a pinned figure (`FigurePin`) plays and then
/// holds still in — the actions that have a clear still frame. Each belongs
/// to an edge (`edges`). Pinned at the top or the bottom where it isn't
/// played, the figure rests there instead. A side only plays the flag (the
/// figure never stands at a side): any other pose pinned at a side plays on
/// the anchor's top. Its raw value is the action's name (`FigurePin.action`).
public enum FigurePose: String, CaseIterable, Hashable, Sendable {
    /// Standing with hands on hips (top), hanging (bottom). Pinned at a
    /// side it stands on the anchor's top.
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
    /// Top: asleep on its side along the edge, the head on one hand, a Z
    /// rising beside it.
    case nap
    /// Top: slipped off the edge, pulled up on both hands behind the card,
    /// the head over the edge, looking around.
    case slip
    /// Top: standing tall with both arms up in a V, a winner on the podium.
    /// Pinnable anywhere; played freely only on anchors that list it
    /// (`figureAnchor(_:edges:actions:)`).
    case celebrate
    /// Top: the champagne going off to the right, the bottle up by the
    /// head, the other fist up. Pinnable anywhere; played freely only
    /// on anchors that list it.
    case champagne
    /// Top: a front double biceps, fists by the ears. Pinnable anywhere;
    /// played freely only on anchors that list it.
    case flex
    /// Bottom: swung out to one side, hanging by its hands.
    case swing
    /// Bottom: pulled up, the head at the edge.
    case pullUp
    /// Sides: a human flag — the body held out flat beside the card.
    case flag

    /// The edges this pose is played at.
    public var edges: FigureEdges {
        switch self {
        case .rest: [.top, .bottom]
        case .wave, .jumpingJacks, .sideStretch, .march, .handstand, .nap, .slip, .celebrate, .champagne, .flex: .top
        case .swing, .pullUp: .bottom
        case .flag: [.leading, .trailing]
        }
    }

    /// The pose's name — the same as the rig's action it plays.
    var name: String { rawValue }

    /// The pose called `name`; nil = no such pose.
    init?(name: String) {
        self.init(rawValue: name)
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
        case .nap: .nap
        case .slip: .slip
        case .celebrate: .celebrate
        case .champagne: .champagne
        case .flex: .flex
        case .swing: .swing
        case .pullUp: .pullUp
        case .flag: .flag
        }
    }
}

/// Pins a stage's figure to one anchor, edge and action — a deterministic,
/// still figure for screenshots, previews and snapshot tests
/// (`figurePinned(_:)`).
///
/// With a pin the stage skips the entrance delay and every random pick: the
/// figure comes out at `edge` of the anchor `anchor` (whatever edges that
/// anchor allows), plays `action` and freezes at its hold frame
/// (`FigureCharacterAction.hold`). An action the character doesn't play at
/// that edge rests there instead — except at a side of ``HumanFigure``,
/// which has no rest there: anything but the flag pinned at a side plays on
/// the anchor's top. An edge it never plays at (or that top, when the
/// figure doesn't fit there) falls back as below. It never
/// loops, ignores taps, and holds the frame also under Reduce Motion, in Low
/// Power Mode and with idle motion off. When the anchor is not on screen or
/// the figure does not fit at that edge, the stage behaves as without a pin
/// (and takes the pin up as soon as it fits).
// Sendable: `anchor` only ever wraps a `Sendable` id (see `init`).
public struct FigurePin: Hashable, @unchecked Sendable {
    /// The anchor's id, as passed to `figureAnchor(_:edges:actions:)`.
    public let anchor: AnyHashable
    /// The edge the figure comes out at.
    public let edge: FigureEdges
    /// The name of the character's action it plays and holds
    /// (`FigureCharacterAction.name`; "rest" = the rest pose).
    public let action: String
    /// The ``HumanFigure`` pose it holds; nil for another character's action.
    public var pose: FigurePose? { FigurePose(rawValue: action) }
    /// Where along the edge, 0…1: left to right on the top and the bottom,
    /// top to bottom at the sides.
    public let spot: Double
    /// true = it comes out and plays up to the hold frame (unless Reduce
    /// Motion is on); false = it shows the hold frame at once.
    public let animated: Bool

    /// A pin at `edge` of the anchor `anchor`, holding `pose`.
    ///
    /// - Parameters:
    ///   - anchor: the id of a view marked with `figureAnchor(_:edges:actions:)`
    ///     under the stage; for `peekingFigure` use `singleCard(edge:pose:spot:animated:)`.
    ///   - edge: a single edge (of several, the first of top, bottom,
    ///     leading, trailing is used; an empty set means top).
    ///   - pose: what it plays and holds; a pose of another edge rests (at
    ///     a side, where only the flag plays, it plays on the anchor's top).
    ///   - spot: where along the edge, 0…1, clamped to the part on screen;
    ///     0.5 (the middle) by default.
    ///   - animated: false = the hold frame at once, no entrance — the
    ///     steadiest choice for snapshots. True by default.
    public init(
        anchor: some Hashable & Sendable, edge: FigureEdges = .top, pose: FigurePose,
        spot: Double = 0.5, animated: Bool = true
    ) {
        self.init(anchor: anchor, edge: edge, action: pose.rawValue, spot: spot, animated: animated)
    }

    /// A pin at `edge` of the anchor `anchor`, holding the character's
    /// action called `action` — for a character of your own
    /// (`FigureCharacterAction.name`).
    ///
    /// - Parameters: as `init(anchor:edge:pose:spot:animated:)`; `action`
    ///   is the action's name ("rest" = the rest pose).
    public init(
        anchor: some Hashable & Sendable, edge: FigureEdges = .top, action: String,
        spot: Double = 0.5, animated: Bool = true
    ) {
        self.init(
            anchor: AnyHashable(anchor), edge: edge, action: action, spot: min(max(spot, 0), 1), animated: animated
        )
    }

    private init(anchor: AnyHashable, edge: FigureEdges, action: String, spot: Double, animated: Bool) {
        self.anchor = anchor
        self.edge = edge
        self.action = action
        self.spot = spot
        self.animated = animated
    }

    /// The pin with its edge as a physical side (`FigureEdges.physical(for:)`).
    func physical(for direction: LayoutDirection) -> FigurePin {
        FigurePin(anchor: anchor, edge: edge.physical(for: direction), action: action, spot: spot, animated: animated)
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

    /// `singleCard(edge:pose:spot:animated:)` for a character's action by name.
    public static func singleCard(
        edge: FigureEdges = .top, action: String, spot: Double = 0.5, animated: Bool = true
    ) -> FigurePin {
        FigurePin(anchor: SoloAnchor.id, edge: edge, action: action, spot: spot, animated: animated)
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
    /// The action's name (`FigureRest.name` when the character does
    /// not play the pinned one at this edge).
    let action: String
    let timeline: FigurePlay
    /// Seconds from the start where it freezes.
    let holdTime: Double

    /// What a pin that is not showing yet waits on: its anchor's frame, so
    /// the stage tries again whenever that card moves. A pin laid out off
    /// screen then shows as soon as its card is scrolled into view — also by
    /// a programmatic scroll, which moves the frames without a scroll phase
    /// and without changing the anchors or the viewports. nil = nothing to
    /// wait for: no pin, the pin already showing, or its anchor not there.
    static func pendingFrame(_ pin: FigurePin?, isShowing: Bool, anchors: [FigureAnchorFrame]) -> CGRect? {
        guard let pin, !isShowing else { return nil }
        return anchors.first { $0.id == pin.anchor }?.rect
    }

    /// The pin's anchor and edge when that anchor is among `anchors` and the
    /// figure fits there and shows whole (`FigureAnchorPicker.isEligible`);
    /// nil = fall back to the free stage. At a side where the character has
    /// no rest (the human) and doesn't play the action, the anchor's top.
    static func resolve(
        _ pin: FigurePin, anchors: [FigureAnchorFrame], viewport stage: CGRect?,
        metrics: PeekingFigureMetrics, style: FigureStyle, character: AnyFigureCharacter = HumanRig.standard
    ) -> FigurePinnedPlay? {
        var edge = pin.figureEdge
        // No rest at a side (the human): what the side doesn't play goes
        // to the anchor's top instead.
        if edge.isSide, !character.geometry.restsAtSides,
           character.pinnedAction(pin.action, at: edge) == FigureRest.name {
            edge = .top
        }
        guard character.geometry.supportedEdges.contains(edge.member),
              let frame = anchors.first(where: { $0.id == pin.anchor }) else { return nil }
        // The anchor's own scroll view, else the stage's.
        let viewport = frame.viewport ?? stage
        guard FigureAnchorPicker.isEligible(rect: frame.rect, edge: edge, viewport: viewport, sizes: metrics.sizes)
        else { return nil }
        let range = metrics.spotRange(at: edge, on: frame.rect, viewport: viewport)
        let action = character.pinnedAction(pin.action, at: edge)
        let timeline = character.play(FigurePlayRequest(
            action: action, entrance: pin.animated ? style.entrance : nil, reduceMotion: false,
            edge: edge, tempo: style.tempo
        ))
        return FigurePinnedPlay(
            anchor: frame.id, edge: edge,
            spot: min(max(pin.spot, range.lowerBound), range.upperBound),
            action: action, timeline: timeline,
            holdTime: timeline.holdTime ?? timeline.duration
        )
    }
}
