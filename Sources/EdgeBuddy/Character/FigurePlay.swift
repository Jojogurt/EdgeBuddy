import SwiftUI

/// One played sequence of a character, as the stage sees it: timing, travel
/// along the edge, still stretches and the pose at a time. `FigureTimeline`
/// (the human rig) and `FigureSequence` (any other character) conform.
protocol FigurePlayable: Sendable {
    var duration: Double { get }
    /// When the figure is fully hidden mid-sequence (it ducked to move
    /// elsewhere), the time to jump to the new spot; nil = it stays.
    var relocatesAt: Double? { get }
    /// While the figure travels along the edge, seconds from the start.
    var walkWindow: ClosedRange<Double>? { get }
    /// How far it travels, the character's units; nil = the stage picks the target.
    var walkDistance: Double? { get }
    /// Set when the sequence ends hidden: how long it stays there, seconds.
    var hiddenPause: Double? { get }
    /// Where a pinned figure freezes, seconds; nil = at the end.
    var holdTime: Double? { get }
    /// Stretches where nothing moves — the animation clock can stop there.
    var stillWindows: [ClosedRange<Double>] { get }
    /// 0…1 along the walk at `time`; nil when the sequence doesn't walk.
    func walkProgress(at time: Double) -> Double?
    /// Opacity at `time` (only the Reduce Motion entrance fades).
    func opacity(at time: Double) -> Double
    /// The pose at `time`, boxed: read once per play, where the next play
    /// starts from (never per frame).
    func anyPose(at time: Double) -> any Sendable
    func isEqual(to other: any FigurePlayable) -> Bool
}

extension FigurePlayable where Self: Equatable {
    func isEqual(to other: any FigurePlayable) -> Bool {
        (other as? Self) == self
    }
}

/// A play with its character's type erased — what the stage keeps between
/// frames. Per frame it is sampled by `AnyFigureCharacter.frame`.
struct FigurePlay: Equatable, Sendable {
    let base: any FigurePlayable

    init(_ base: any FigurePlayable) {
        self.base = base
    }

    /// Nothing played yet: hidden, no pose.
    static let idle = FigurePlay(FigureIdlePlay())

    var duration: Double { base.duration }
    var relocatesAt: Double? { base.relocatesAt }
    var walkWindow: ClosedRange<Double>? { base.walkWindow }
    var walkDistance: Double? { base.walkDistance }
    var hiddenPause: Double? { base.hiddenPause }
    var holdTime: Double? { base.holdTime }
    var stillWindows: [ClosedRange<Double>] { base.stillWindows }
    func walkProgress(at time: Double) -> Double? { base.walkProgress(at: time) }
    func opacity(at time: Double) -> Double { base.opacity(at: time) }
    func anyPose(at time: Double) -> any Sendable { base.anyPose(at: time) }

    static func == (lhs: FigurePlay, rhs: FigurePlay) -> Bool {
        lhs.base.isEqual(to: rhs.base)
    }
}

/// The empty play before the first entrance.
struct FigureIdlePlay: FigurePlayable, Equatable {
    var duration: Double { 0 }
    var relocatesAt: Double? { nil }
    var walkWindow: ClosedRange<Double>? { nil }
    var walkDistance: Double? { nil }
    var hiddenPause: Double? { nil }
    var holdTime: Double? { nil }
    var stillWindows: [ClosedRange<Double>] { [] }
    func walkProgress(at time: Double) -> Double? { nil }
    func opacity(at time: Double) -> Double { 1 }
    func anyPose(at time: Double) -> any Sendable { self }
}

extension FigureTimeline: FigurePlayable {
    func anyPose(at time: Double) -> any Sendable { joints(at: time) }
}

/// One frame ready to show: whether it takes taps, whether the stage
/// mirrors it, and the drawing (in the character's units; the canvas has
/// scaled and translated the context to the edge's box).
struct FigureFrame {
    /// Out from behind the card far enough to tap.
    var isOut: Bool
    /// Mirrored horizontally around the box's middle (heading left).
    var isMirrored = false
    var draw: (inout GraphicsContext, Color) -> Void
}

/// What the stage asks a character to play.
struct FigurePlayRequest {
    /// The action's name; `FigureActionName.rest` = only the rest pose.
    var action: String
    /// How it comes out from behind the card first; nil = already out.
    var entrance: FigureEntrance?
    var reduceMotion: Bool
    var edge: FigureEdge = .top
    /// Duck behind the card first, then come out elsewhere.
    var relocating = false
    /// The edge it ducks from when relocating.
    var previousEdge: FigureEdge?
    /// The pose shown when the play starts (`FigurePlay.anyPose`).
    var previousPose: (any Sendable)?
    var tempo: Double = 1
    var variation: FigureVariation = .standard
}

/// What the stage needs to know about one action before playing it.
struct FigureActionInfo: Equatable, Sendable {
    /// Travel along the edge per beat, the character's units; nil = in place.
    var travelPerBeat: Double?
    /// Beats per looped cycle (`FigureVariation.repeats`).
    var repeatRange: ClosedRange<Int>
    /// Beats when not looping.
    var defaultRepeats: Int
}

enum FigureActionName {
    /// The rest action every character has: standing (or hanging, or
    /// peeking) at the edge's rest pose.
    static let rest = "rest"
}
