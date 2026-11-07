import SwiftUI

/// An edge of a marked view (`figureAnchor(_:edges:)`) a character plays at.
///
/// Top: it stands on the edge, the rest hidden below it. Bottom: it hangs
/// under the edge, hidden above it. Sides: it plays beside the card, outside
/// its edge; the card hides whatever is behind it. A character draws the
/// sides as the trailing one (the card to the left of its box); at the
/// leading side the stage shows the mirror image.
public enum FigureEdge: CaseIterable, Hashable, Sendable {
    case top, bottom, leading, trailing
}

/// A character's pose: whatever describes one frame of it (joint angles,
/// offsets, a squash). The stage blends between poses, so it must
/// interpolate.
public protocol FigureCharacterPose: Equatable, Sendable {
    /// A blend from this pose to `other`: `t` = 0 is this pose, 1 is
    /// `other`. `t` may overshoot 0…1 a little (springy easings) — a linear
    /// blend of every value handles that.
    func interpolated(to other: Self, _ t: Double) -> Self
}

/// The part of a character's own coordinate space (its "units", y down)
/// drawn at one edge, and where the card's edge runs through it.
///
/// The stage scales the units so that `FigureCharacter.referenceHeight`
/// is `figureHeight(_:)` points, puts the box against the card with `edge`
/// on the card's edge, and clips the drawing to the box — so whatever lies
/// past the card's edge inside the box would show over the card. Keep the
/// box on the outside of the edge (the human's boxes end right at it, or
/// overlap it only by the gripping hands).
public struct FigureCharacterBox: Equatable, Sendable {
    /// The drawn rectangle, in the character's units. It is also the tap area.
    public var rect: CGRect
    /// The card's edge in the same units: a y for the top (usually
    /// `rect.maxY`) and the bottom (usually `rect.minY`), an x for the sides
    /// (usually `rect.minX`; the card lies to the left of it).
    public var edge: CGFloat

    /// A box `rect` whose card edge is at `edge`.
    public init(_ rect: CGRect, edge: CGFloat) {
        self.rect = rect
        self.edge = edge
    }
}

/// A stretch of motion: a pose for every moment of `duration` seconds.
public struct FigureMotion<Pose: FigureCharacterPose>: Sendable {
    /// Length at tempo 1, seconds.
    public let duration: Double
    private let sample: @Sendable (Double) -> Pose

    /// A motion whose pose at `time` (0…`duration` seconds) is `pose(time)`.
    /// It runs on every frame while it plays: keep it cheap and allocation-free.
    public init(duration: Double, pose: @escaping @Sendable (_ time: Double) -> Pose) {
        self.duration = max(duration, 0)
        self.sample = pose
    }

    /// A motion through `poses`, evenly spread over `duration` (the first at
    /// 0, the last at `duration`), each step eased in and out.
    public init(duration: Double, through poses: [Pose]) {
        precondition(!poses.isEmpty, "FigureMotion needs at least one pose")
        let steps = Double(max(poses.count - 1, 1))
        self.init(duration: duration) { time in
            guard poses.count > 1, duration > 0 else { return poses[0] }
            let position = min(max(time / duration, 0), 1) * steps
            let index = min(Int(position), poses.count - 2)
            let u = position - Double(index)
            return poses[index].interpolated(to: poses[index + 1], u * u * (3 - 2 * u))
        }
    }

    /// The pose at `time` seconds, clamped to 0…`duration`.
    public func pose(at time: Double) -> Pose {
        sample(min(max(time, 0), duration))
    }
}

/// Something a character does at an edge: one beat of motion, repeated a
/// few times per play, optionally travelling along the edge.
///
/// A play goes: out from behind the card (`FigureCharacter.entrance(at:)`),
/// a moment at rest, a short blend into the beat's first pose, the beat
/// `repeats` times, a blend back to rest, and — while the stage loops —
/// back behind the card (the entrance played backwards).
public struct FigureCharacterAction<Pose: FigureCharacterPose>: Sendable {
    /// Unique among the character's actions at an edge; pins refer to it
    /// (`FigurePin(anchor:edge:action:)`). "rest" is reserved for the rest pose.
    public var name: String
    /// One beat.
    public var motion: FigureMotion<Pose>
    /// Beats per play: a random count in this range each looped cycle; the
    /// lower bound when the stage does not loop.
    public var repeats: ClosedRange<Int>
    /// How far the figure moves along the edge per beat, in the character's
    /// units: along the top (toward the wider side) or up a side (as far as
    /// the visible side allows — a side's travelling action always ends at
    /// the top). Zero = it stays in place. Nothing travels under a bottom edge.
    public var travel: Double
    /// Where a pinned figure (`figurePinned(_:)`) freezes, seconds into the
    /// first beat; nil = half-way through it.
    public var hold: Double?
    /// false = not played at a side less than ~28 pt from the screen's edge,
    /// where there is no room beside the card (the human only climbs there).
    public var playsAtScreenEdge: Bool

    /// The room along the edge it needs: `travel` times the fewest beats.
    /// Edges with less room on screen don't offer it.
    public var minimumRoom: Double { travel * Double(repeats.lowerBound) }

    /// An action called `name` playing `motion` per beat.
    public init(
        _ name: String, motion: FigureMotion<Pose>, repeats: ClosedRange<Int> = 1...1,
        travel: Double = 0, hold: Double? = nil, playsAtScreenEdge: Bool = true
    ) {
        self.name = name
        self.motion = motion
        self.repeats = max(repeats.lowerBound, 1)...max(repeats.upperBound, 1)
        self.travel = max(travel, 0)
        self.hold = hold
        self.playsAtScreenEdge = playsAtScreenEdge
    }
}

/// Everything about a figure: its pose model, what it does at each edge,
/// how much room it needs there and how it looks. The stage
/// (`figureStage(isEnabled:style:isWaiting:loops:)`, `peekingFigure`) picks
/// the anchor, edge and spot, sequences the play (entrance, holds, beats,
/// exit), handles taps, Reduce Motion, Low Power Mode and pins, and asks the
/// character for the rest. Set it with `figureCharacter(_:)`; the default is
/// ``HumanFigure``.
///
/// - Coordinates are the character's own units, y down. Per edge the
///   character says which part of them is drawn (`box(at:)`) and where the
///   card's edge runs; `referenceHeight` units are `figureHeight(_:)` points.
/// - Sides are authored as the trailing side (the card on the left); the
///   stage mirrors the leading side, and the top and bottom while the
///   figure travels left. Leading and trailing are logical: in
///   right-to-left layouts they swap like the anchors' edges.
/// - An edge with no actions (`actions(at:)` empty) is never used.
/// - `draw` and the actions' `pose(at:)` run on every frame (60–120 Hz
///   while moving): keep them cheap — no image or view resolution beyond a
///   symbol or a short text, no allocations you can avoid.
/// - Reduce Motion: the figure fades in at the rest pose and stands. Low
///   Power Mode: it comes out to the rest pose and plays nothing.
///
/// ``HumanFigure`` conforms too; the stage plays it with its own richer
/// sequencing (climb and spring entrances, hands-first side routes, grips
/// held by IK while it moves), which its `actions(at:)` describe as whole plays.
public protocol FigureCharacter: Sendable {
    /// The character's pose model.
    associatedtype Pose: FigureCharacterPose

    /// How many units `figureHeight(_:)` spans: by default the top box from
    /// its top down to the card's edge.
    var referenceHeight: CGFloat { get }

    /// The part of the character's space drawn at `edge`, with the card's
    /// edge line. Asked for every edge (also unused ones).
    func box(at edge: FigureEdge) -> FigureCharacterBox

    /// What it may play at `edge`, drawn at random (never the same twice in
    /// a row when there is another). Empty = it never comes out at `edge`.
    func actions(at edge: FigureEdge) -> [FigureCharacterAction<Pose>]

    /// The pose every play at `edge` starts and ends in, out from behind the card.
    func restPose(at edge: FigureEdge) -> Pose

    /// Fully behind the card at `edge` (nothing inside the box shows).
    func hiddenPose(at edge: FigureEdge) -> Pose

    /// How it comes out at `edge`: from `hiddenPose(at:)` to `restPose(at:)`.
    /// Played backwards to go back. nil (the default) = a rise from the
    /// hidden pose to the rest pose with a small overshoot, 0.5 s.
    func entrance(at edge: FigureEdge) -> FigureMotion<Pose>?

    /// Draws `pose` in the character's units (the context is already scaled
    /// and translated to the edge's box) in `color` (`figureColor(_:)`).
    func draw(_ pose: Pose, in context: inout GraphicsContext, color: Color)
}

extension FigureCharacter {
    public var referenceHeight: CGFloat {
        let top = box(at: .top)
        return top.edge - top.rect.minY
    }

    public func entrance(at edge: FigureEdge) -> FigureMotion<Pose>? { nil }
}

extension EnvironmentValues {
    /// The stage's character (`figureCharacter(_:)`); nil = `HumanFigure`.
    @Entry var figureCharacter: AnyFigureCharacter?
}

extension View {
    /// Sets the character every figure stage in this view hierarchy plays:
    /// ``HumanFigure`` (the default, tuned by its parameters) or a type of
    /// your own conforming to ``FigureCharacter``.
    ///
    /// ```swift
    /// ScrollView { … }
    ///     .figureStage()
    ///     .figureCharacter(Ghost())
    /// ```
    ///
    /// Switching to another character type starts the figure over (behind
    /// the cards); the same type with other parameters takes effect at once.
    ///
    /// - Parameter character: who plays.
    public func figureCharacter(_ character: some FigureCharacter) -> some View {
        environment(\.figureCharacter, AnyFigureCharacter(character))
    }
}
