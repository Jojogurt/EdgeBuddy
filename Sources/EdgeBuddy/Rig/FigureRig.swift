import CoreGraphics
import Foundation

/// What the peeking figure does after it steps onto the card's edge. The
/// stage draws one at random each cycle (`FigureRepertoire`).
enum FigureAction: Equatable, Sendable {
    /// Hands on hips, a short nod — the resting state every action ends in.
    case rest
    /// A greeting.
    case wave
    case jumpingJacks
    /// A side bend.
    case sideStretch
    /// Marching in place: knees up, arms pumping.
    case march
    /// Marching along the card's edge to another spot
    /// (`FigureTimeline.walkWindow`).
    case walk
    /// Turns sideways and runs along the card's edge to another spot — the
    /// loader's run cycle (`FigureJoints.run(phase:)`), the same rig in profile.
    case run
    /// Bottom edge: swings on its hands like a pendulum, legs trailing.
    case swing
    /// Bottom edge: pulls itself up until the head reaches the edge.
    case pullUp
    /// Side edge: leans further out from behind the edge and looks around.
    case peek
    /// Side edge: both hands on the edge, body held out flat over the card.
    case flag
    /// Side edge: turns to the card and climbs along its edge to another
    /// spot (`FigureTimeline.walkWindow`).
    case climb
}

/// The edge of an anchor the figure is at. Top: stands on it, the rest
/// hidden below. Bottom: hangs under it, hidden above. Sides: in front of the
/// card, cut by the edge — the hidden part is outside the card. Drawn as the
/// trailing side; leading is its mirror image.
enum FigureEdge: CaseIterable, Hashable, Sendable {
    case top, bottom, leading, trailing

    var isSide: Bool { self == .leading || self == .trailing }

    /// The `FigureEdges` member for this edge.
    var member: FigureEdges {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }

    /// How often this edge is drawn among the allowed, visible ones
    /// (top 60%, bottom 20%, each side 10%).
    var weight: Double {
        switch self {
        case .top: 0.6
        case .bottom: 0.2
        case .leading, .trailing: 0.1
        }
    }
}

/// Random spice for one looped cycle (`peekingFigure(_:loops:)`): how long
/// it stands before and after the action, how many times the action repeats,
/// how it leaves and how long it stays hidden. `.standard` = a single play
/// with the canvas counts that ends standing.
struct FigureVariation: Equatable, Sendable {
    /// Standing at rest after the entrance, before the action, seconds.
    var holdBefore: Double = 0
    /// Repetitions of the action's beat (waves, jacks, step pairs, run
    /// cycles, stretches, nods); nil = the canvas count.
    var repeats: Int?
    /// Standing at rest after the action, before leaving, seconds.
    var holdAfter: Double = 0
    /// Leaves behind the card with this entrance played in reverse; nil = it
    /// stays standing.
    var exit: FigureEntrance?
    /// Hidden behind the card after the exit, before the next cycle, seconds.
    var hiddenPause: Double = 0
    /// Multiplies the style's tempo for this cycle.
    var tempoScale: Double = 1

    static let standard = FigureVariation()

    static let holdBeforeRange = 0.4...1.6
    static let holdAfterRange = 0.5...2.0
    static let hiddenPauseRange = 0.8...3.2
    static let tempoScaleRange = 0.88...1.15

    /// Repetition range per action (canvas count inside it).
    static func repeatRange(_ action: FigureAction) -> ClosedRange<Int> {
        switch action {
        case .rest: 1...2
        case .wave, .jumpingJacks, .march, .walk: 2...4
        case .sideStretch: 1...2
        case .run: 3...5
        case .swing, .flag, .climb: 2...4
        case .pullUp, .peek: 1...3
        }
    }

    /// One looped cycle of `action`, leaving with `exit`.
    static func random(
        for action: FigureAction, exit: FigureEntrance, using generator: inout some RandomNumberGenerator
    ) -> FigureVariation {
        FigureVariation(
            holdBefore: .random(in: holdBeforeRange, using: &generator),
            repeats: .random(in: repeatRange(action), using: &generator),
            holdAfter: .random(in: holdAfterRange, using: &generator),
            exit: exit,
            hiddenPause: .random(in: hiddenPauseRange, using: &generator),
            tempoScale: .random(in: tempoScaleRange, using: &generator)
        )
    }
}

/// Joint angles of the figure rig, in degrees. A segment at angle `a` points
/// along `(sin a, cos a)` in the 100×84 grid: 0 = down, 90 = right, 180 = up,
/// -90 = left. Upper arms and thighs are absolute, elbows and knees bend
/// relative to them. 1:1 with the "Sztafeta" canvas (`C_ludzik`).
struct FigureJoints: Equatable, Sendable {
    var armL: Double
    var elbowL: Double
    var armR: Double
    var elbowR: Double
    var legL: Double
    var kneeL: Double
    var legR: Double
    var kneeR: Double
    /// Torso tilt around the hip (+ = right). Arms turn with the torso.
    var lean: Double
    /// Body offset in grid units (- = up). 64 hides the figure behind the card.
    var y: Double
    /// Head tilt on top of the lean.
    var tilt: Double
    /// 0 = seen from the front, 1 = in profile (the run): shoulders and hips
    /// close to one point, the far limbs (`L`) fade to `farLimbOpacity`.
    /// Blends, so the figure turns instead of snapping.
    var profile: Double = 0
    /// Horizontal mirror around the hip: 1 = as drawn, -1 = mirrored (a run
    /// to the left). Values in between squash the figure mid-turn.
    var facing: Double = 1
    /// Body offset in grid units (+ = right) — the side and bottom edges.
    var x: Double = 0

    /// Opacity of the far arm and leg in profile (canvas `S_loadery`).
    static let farLimbOpacity = 0.45

    /// Hands on hips (elbows out), standing straight on the card's edge.
    static let rest = FigureJoints(
        armL: -50, elbowL: 103, armR: 50, elbowR: -103,
        legL: -5, kneeL: 0, legR: 5, kneeR: 0, lean: 0, y: 0, tilt: 0
    )

    /// One step of the run, seen from the side facing right (canvas
    /// `S_loadery`, 1:1). `phase` in steps: one full cycle (both legs) is
    /// `runCycle` seconds. Near limbs are `R`, far limbs `L`.
    static func run(phase: Double) -> FigureJoints {
        let phi = 2 * .pi * phase
        let s = sin(phi)
        func knee(_ sv: Double) -> Double { -(12 + 58 * (1 - sv) / 2) }
        return FigureJoints(
            armL: 42 * s, elbowL: 88, armR: -42 * s, elbowR: 88,
            legL: -38 * s, kneeL: knee(-s), legR: 38 * s, kneeR: knee(s),
            lean: 9, y: -2.5 * abs(cos(phi)), tilt: 0, profile: 1, facing: 1
        )
    }

    /// Length of one run cycle (two steps), seconds at tempo 1.
    static let runCycle = 0.66

    /// A copy with some joints changed.
    func with(_ change: (inout FigureJoints) -> Void) -> FigureJoints {
        var copy = self
        change(&copy)
        return copy
    }

    /// Linear blend of every joint, `t` in 0…1 (may overshoot for back-out).
    func interpolated(to other: FigureJoints, _ t: Double) -> FigureJoints {
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return FigureJoints(
            armL: mix(armL, other.armL), elbowL: mix(elbowL, other.elbowL),
            armR: mix(armR, other.armR), elbowR: mix(elbowR, other.elbowR),
            legL: mix(legL, other.legL), kneeL: mix(kneeL, other.kneeL),
            legR: mix(legR, other.legR), kneeR: mix(kneeR, other.kneeR),
            lean: mix(lean, other.lean), y: mix(y, other.y), tilt: mix(tilt, other.tilt),
            profile: mix(profile, other.profile), facing: mix(facing, other.facing), x: mix(x, other.x)
        )
    }
}

/// Poses of the bottom and side edges (canvas `S_ludzik_krawedzie`,
/// 1:1). Hands on an edge are held by two-bone IK, solved once on the canvas:
/// the grips stay put while the body moves.
enum FigureEdgePoses {
    private static let rest = FigureJoints.rest

    // MARK: Bottom — hanging under the card's edge (grid y `bottomEdgeY`)

    /// The card's bottom edge in the rig's grid: the hanging hands grip it.
    static let bottomEdgeY = 18.0

    /// Hanging straight-armed under the edge — the bottom's rest.
    static let hang = rest.with {
        $0.armL = -168; $0.elbowL = 0; $0.armR = 168; $0.elbowR = 0; $0.legL = -3; $0.legR = 3
    }
    /// The bottom's nod: hanging, head tilted.
    static let hangSag = hang.with { $0.legL = -5; $0.legR = 5; $0.tilt = 5 }
    static let pullMid = rest.with {
        $0.armL = 165; $0.elbowL = 59.9; $0.armR = -165; $0.elbowR = -59.9
        $0.legL = -4; $0.kneeL = 8; $0.legR = 4; $0.kneeR = -8; $0.y = -4
    }
    /// Pulled up, the head at the edge, knees drawn up.
    static let pullTop = rest.with {
        $0.armL = 155.4; $0.elbowL = 85.7; $0.armR = -155.4; $0.elbowR = -85.7
        $0.legL = -6; $0.kneeL = 18; $0.legR = 6; $0.kneeR = -18; $0.y = -8
    }
    /// Fully behind the card, above its bottom edge.
    static let hangHidden = pullTop.with { $0.y = -96 }
    /// The pendulum's ends: the body turns around the hands, legs lag.
    static let swingRight = rest.with {
        $0.armL = -171.8; $0.elbowL = 6.7; $0.armR = -164.1; $0.elbowR = -61.1
        $0.legL = 15; $0.kneeL = -8.4; $0.legR = 21; $0.kneeR = -8.4
        $0.lean = -11; $0.x = 9.2; $0.y = -2.9; $0.tilt = -3.3
    }
    static let swingLeft = rest.with {
        $0.armL = 164.1; $0.elbowL = 61.1; $0.armR = 171.8; $0.elbowR = -6.7
        $0.legL = -21; $0.kneeL = 8.4; $0.legR = -15; $0.kneeR = 8.4
        $0.lean = 11; $0.x = -9.2; $0.y = -2.9; $0.tilt = 3.3
    }

    // MARK: Side — drawn at the trailing edge (grid x `sideEdgeX`), card to the left

    /// The card's side edge in the rig's grid: everything right of it is
    /// outside the card and never shows.
    static let sideEdgeX = 100.0

    /// Leaning in from behind the edge, head first, a hand on the card's
    /// edge — the side's rest.
    static let peek = rest.with {
        $0.armL = -63.3; $0.elbowL = 123.6; $0.legL = -4; $0.legR = 6
        $0.lean = -18; $0.x = 56; $0.tilt = -10
    }
    /// The side's nod.
    static let peekTilt = peek.with { $0.tilt = 4 }
    static let peekOut = peek.with { $0.armL = -40.7; $0.elbowL = 117.4; $0.lean = -28; $0.x = 52; $0.tilt = -14 }
    static let peekLook = peekOut.with { $0.tilt = -2 }
    /// Fully outside the card, past its side edge.
    static let sideHidden = peek.with { $0.x = 82 }
    /// Swinging out from the peek into the flag.
    static let flagSwing = rest.with {
        $0.armL = 85.6; $0.elbowL = 106.9; $0.armR = 134.9; $0.elbowR = -117.6
        $0.legL = -40; $0.kneeL = 10; $0.legR = -30; $0.kneeR = -10
        $0.lean = 40; $0.x = 20; $0.y = -6; $0.tilt = -6
    }
    /// The flag, legs scissoring between `flagA` and `flagB`.
    static let flagA = rest.with {
        $0.armL = 165.7; $0.elbowL = 52.7; $0.armR = -165.7; $0.elbowR = -52.7
        $0.legL = -80; $0.legR = -100; $0.lean = 90; $0.y = -18
    }
    static let flagB = flagA.with { $0.legL = -98; $0.legR = -84 }
    /// Climbing along the edge in profile, facing the card; hip just outside.
    static let climbA = rest.with {
        $0.armL = 95; $0.elbowL = 70; $0.armR = 165; $0.elbowR = -12
        $0.legL = 12; $0.kneeL = -22; $0.legR = 100; $0.kneeR = -100
        $0.lean = 8; $0.x = 54; $0.profile = 1; $0.facing = -1
    }
    static let climbB = climbA.with {
        $0.armL = 165; $0.elbowL = -12; $0.armR = 95; $0.elbowR = 70
        $0.legL = 100; $0.kneeL = -100; $0.legR = 12; $0.kneeR = -22
    }
}

/// One played sequence: optional entrance, then the action, ending at rest.
/// Pure data — sampled by time, so it is testable without a view.
struct FigureTimeline: Equatable, Sendable {
    enum Easing: Equatable, Sendable {
        /// Smoothstep `u²(3−2u)`.
        case inOut
        /// Back-out with a small overshoot (the entrance spring).
        case out
        /// Accelerating cubic — ducking behind the card.
        case `in`
        /// Straight blend — densely sampled cycles (the run).
        case linear
        /// `out` played backwards: a small dip, then accelerating away.
        case backIn
        /// `in` played backwards: fast start, settling.
        case outCubic

        /// The same segment played backwards (an exit from an entrance).
        var reversed: Easing {
            switch self {
            case .inOut: .inOut
            case .linear: .linear
            case .out: .backIn
            case .backIn: .out
            case .in: .outCubic
            case .outCubic: .in
            }
        }
    }

    struct Keyframe: Equatable, Sendable {
        /// Absolute time from the start, seconds.
        var time: Double
        var joints: FigureJoints
        /// Easing of the segment that ends at this keyframe.
        var easing: Easing
    }

    let keyframes: [Keyframe]
    /// Reduce Motion: the figure fades in (0.2 s) instead of moving.
    let fadesIn: Bool
    /// When the figure is fully hidden behind the card mid-sequence (it ducked
    /// to move elsewhere), the time to jump to the new spot; nil = it stays.
    let relocatesAt: Double?

    /// While `walk` plays, the figure travels along the edge (seconds from
    /// the start); nil = it stays put.
    let walkWindow: ClosedRange<Double>?

    /// Set when the sequence ends hidden behind the card (`FigureVariation.exit`):
    /// how long it stays there before the next cycle, seconds.
    let hiddenPause: Double?

    /// How far below the rig's own ground line (grid y 84) the card's edge
    /// sits for the peeking figure (`FigureSkeleton.edgeY`): poses "behind
    /// the card" are this much lower, so the standing feet end on the edge.
    static let behind = Double(FigureSkeleton.edgeY - FigureSkeleton.gridSize.height)

    /// Lowers the run (its bent strides reach less far down than standing
    /// legs, canvas `S_loadery`) so the lowest foot touches the edge like the
    /// standing feet instead of floating above it.
    static let runDrop = 3.0

    private static func run(phase: Double) -> FigureJoints {
        FigureJoints.run(phase: phase).with { $0.y += runDrop }
    }

    /// Ducking behind the card before moving to a new spot, seconds.
    static let duckDuration = 0.24

    /// Length of each entrance at tempo 1, seconds.
    static func entranceDuration(_ entrance: FigureEntrance) -> Double {
        switch entrance {
        case .climb: 1.4
        case .spring: 0.66
        }
    }

    var duration: Double { keyframes.last?.time ?? 0 }

    /// The resting pose every timeline settles into.
    var final: FigureJoints { keyframes.last?.joints ?? .rest }

    /// - Parameters:
    ///   - entrance: how it comes out from behind the card first; nil = it
    ///     is already standing.
    ///   - edge: the anchor's edge it plays at; `entrance` only picks the
    ///     top's entrance, the other edges have their own (`entranceSteps`).
    ///   - relocating: duck behind the card first, then come out elsewhere
    ///     (`relocatesAt`) with `entrance` (spring when nil) and play.
    ///   - previousEdge: the edge it ducks from when relocating (default `edge`).
    ///   - tempo: playback speed (`FigureStyle.tempo`); every time scales by 1/tempo.
    ///   - variation: holds, repeat count and exit of a looped cycle.
    init(
        action: FigureAction, entrance: FigureEntrance?, reduceMotion: Bool, edge: FigureEdge = .top,
        relocating: Bool = false, from previousEdge: FigureEdge? = nil,
        tempo: Double = 1, variation: FigureVariation = .standard
    ) {
        let pace = max(tempo * variation.tempoScale, 0.1)
        var frames: [Keyframe] = []
        var time = 0.0
        func at(_ dt: Double, _ joints: FigureJoints, _ easing: Easing = .inOut) {
            time += dt / pace
            frames.append(Keyframe(time: time, joints: joints, easing: easing))
        }
        let rest = Self.restPose(edge)
        let poses = FigureEdgePoses.self
        var walk: ClosedRange<Double>?

        if reduceMotion {
            frames.append(Keyframe(time: 0, joints: rest, easing: .inOut))
            // A fixed crossfade, independent of tempo.
            frames.append(Keyframe(time: entrance != nil ? 0.2 : 0.01, joints: rest, easing: .inOut))
            keyframes = frames
            fadesIn = entrance != nil
            relocatesAt = nil
            walkWindow = nil
            hiddenPause = nil
            return
        }

        let comesOut = relocating ? (entrance ?? .spring) : entrance
        let hidden = comesOut.map { Self.hiddenPose($0, edge: edge) } ?? rest
        func hold(_ seconds: Double) {
            guard seconds > 0 else { return }
            time += seconds
            frames.append(Keyframe(time: time, joints: rest, easing: .inOut))
        }
        if relocating {
            let before = previousEdge ?? edge
            frames.append(Keyframe(time: 0, joints: Self.restPose(before), easing: .inOut))
            at(Self.duckDuration, Self.duckPose(before), .in)
            relocatesAt = time
            // Jump straight to the new edge's hidden pose: poses of one edge
            // may show at another.
            frames.append(Keyframe(time: time, joints: hidden, easing: .inOut))
            at(0.12, hidden)
        } else {
            frames.append(Keyframe(time: 0, joints: hidden, easing: .inOut))
            relocatesAt = nil
        }
        if let comesOut {
            for (dt, pose, easing) in Self.entranceSteps(comesOut, edge: edge) { at(dt, pose, easing) }
        }
        hold(variation.holdBefore)

        switch action {
        case .rest:
            for _ in 0..<(variation.repeats ?? 1) {
                switch edge {
                case .top:
                    at(0.2, rest.with { $0.tilt = 9 })
                    at(0.28, rest)
                case .bottom:
                    at(0.2, poses.hangSag)
                    at(0.28, rest)
                case .leading, .trailing:
                    at(0.24, poses.peekTilt)
                    at(0.3, rest)
                }
            }
        case .swing:
            at(0.42, poses.swingRight)
            for _ in 0..<(variation.repeats ?? 2) {
                at(0.56, poses.swingLeft)
                at(0.56, poses.swingRight)
            }
            at(0.5, rest)
        case .pullUp:
            for _ in 0..<(variation.repeats ?? 2) {
                at(0.3, poses.pullMid)
                at(0.16, poses.pullTop)
                at(0.14, poses.pullTop)
                at(0.42, rest)
            }
        case .peek:
            for _ in 0..<(variation.repeats ?? 2) {
                at(0.35, poses.peekOut)
                at(0.3, poses.peekLook)
                at(0.25, poses.peekOut)
                at(0.35, rest)
            }
            at(0.24, poses.peekTilt)
            at(0.3, rest)
        case .flag:
            at(0.4, poses.flagSwing)
            at(0.35, poses.flagA, .out)
            for _ in 0..<(variation.repeats ?? 3) {
                at(0.22, poses.flagB)
                at(0.22, poses.flagA)
            }
            at(0.35, poses.flagSwing)
            at(0.42, rest)
        case .climb:
            at(0.3, poses.climbA)
            let climbStart = time
            for _ in 0..<(variation.repeats ?? 3) {
                at(0.35, poses.climbB)
                at(0.35, poses.climbA)
            }
            walk = climbStart...time
            at(0.32, rest)
        case .wave:
            let up = rest.with {
                $0.armL = -8; $0.elbowL = 4; $0.armR = 148; $0.elbowR = -18; $0.tilt = -7
            }
            at(0.3, up)
            for _ in 0..<(variation.repeats ?? 3) {
                at(0.2, up.with { $0.elbowR = 24 })
                at(0.2, up.with { $0.elbowR = -34 })
            }
            at(0.18, up)
            at(0.42, rest)
        case .jumpingJacks:
            let closed = rest.with {
                $0.armL = -9; $0.elbowL = 0; $0.armR = 9; $0.elbowR = 0; $0.legL = -4; $0.legR = 4
            }
            let open = rest.with {
                $0.armL = -150; $0.elbowL = -22; $0.armR = 150; $0.elbowR = 22
                $0.legL = -21; $0.kneeL = 4; $0.legR = 21; $0.kneeR = -4
            }
            let air = closed.interpolated(to: open, 0.5).with { $0.y = -9 }
            at(0.22, closed)
            for _ in 0..<(variation.repeats ?? 3) {
                at(0.15, air)
                at(0.15, open)
                at(0.15, air)
                at(0.15, closed)
            }
            at(0.34, rest)
        case .sideStretch:
            let up = rest.with {
                $0.armL = -150; $0.elbowL = -22; $0.armR = 150; $0.elbowR = 22; $0.legL = -7; $0.legR = 7
            }
            let toLeft = up.with {
                $0.armL = -63; $0.elbowL = 90; $0.armR = 147; $0.elbowR = 65; $0.lean = -18; $0.tilt = -12
            }
            let toRight = up.with {
                $0.armL = -147; $0.elbowL = -65; $0.armR = 63; $0.elbowR = -90; $0.lean = 18; $0.tilt = 12
            }
            at(0.35, up)
            for round in 0..<(variation.repeats ?? 1) {
                if round > 0 { at(0.45, up) }
                at(0.55, toLeft)
                at(0.45, toLeft)
                at(0.45, up)
                at(0.55, toRight)
                at(0.45, toRight)
            }
            at(0.4, up)
            at(0.42, rest)
        case .march, .walk:
            // Front view: a raised knee pokes out sideways above the edge,
            // the opposite fist pumps up, the body bobs on each step.
            let neutral = rest.with {
                $0.armL = -10; $0.elbowL = 0; $0.armR = 10; $0.elbowR = 0
            }
            let leftUp = neutral.with {
                $0.legL = -60; $0.kneeL = 60; $0.armR = 25; $0.elbowR = 95
                $0.y = -3; $0.tilt = 4
            }
            let rightUp = neutral.with {
                $0.legR = 60; $0.kneeR = -60; $0.armL = -25; $0.elbowL = -95
                $0.y = -3; $0.tilt = -4
            }
            at(0.25, neutral)
            let walkStart = time
            for _ in 0..<(variation.repeats ?? 3) {
                at(0.22, leftUp)
                at(0.18, neutral)
                at(0.22, rightUp)
                at(0.18, neutral)
            }
            walk = action == .walk ? walkStart...time : nil
            at(0.3, rest)
        case .run:
            // Turn sideways into the first stride, run `runCycles` cycles
            // (sampled densely, linear in between), turn back to the front.
            at(0.22, Self.run(phase: 0))
            let runStart = time
            let samples = Self.runSamplesPerCycle
            for i in 1...((variation.repeats ?? Self.runCycles) * samples) {
                at(FigureJoints.runCycle / Double(samples), Self.run(phase: Double(i) / Double(samples)), .linear)
            }
            walk = runStart...time
            at(0.3, rest)
        }
        if let exit = variation.exit {
            hold(variation.holdAfter)
            for (dt, pose, easing) in Self.exitSteps(exit, edge: edge) { at(dt, pose, easing) }
            hiddenPause = variation.hiddenPause
        } else {
            hiddenPause = nil
        }
        keyframes = frames
        fadesIn = false
        walkWindow = walk
    }

    /// The steps from `hiddenPose(entrance, edge:)` up to the edge's rest.
    /// Only the top uses `entrance`: the bottom lowers itself from behind the
    /// card on bent arms and straightens into the hang; a side slides in from
    /// outside the card, head first.
    static func entranceSteps(
        _ entrance: FigureEntrance, edge: FigureEdge = .top
    ) -> [(Double, FigureJoints, Easing)] {
        let poses = FigureEdgePoses.self
        switch edge {
        case .bottom:
            return [
                (0.5, poses.pullTop, .inOut), (0.32, poses.hang, .inOut),
                (0.14, poses.hangSag, .inOut), (0.18, poses.hang, .inOut),
            ]
        case .leading, .trailing:
            return [(0.42, poses.peek, .out), (0.14, poses.peek, .inOut)]
        case .top:
            break
        }
        let rest = FigureJoints.rest
        switch entrance {
        case .spring:
            return [(0.36, rest.with { $0.y = -3 }, .out), (0.16, rest, .inOut), (0.14, rest, .inOut)]
        case .climb:
            return climbSteps
        }
    }

    /// The entrance played backwards: from rest down to `hiddenPose(entrance)`,
    /// each segment with the same length and the reversed easing.
    static func exitSteps(
        _ entrance: FigureEntrance, edge: FigureEdge = .top
    ) -> [(Double, FigureJoints, Easing)] {
        let steps = entranceSteps(entrance, edge: edge)
        let poses = [hiddenPose(entrance, edge: edge)] + steps.map(\.1)
        return steps.indices.reversed().map { i in (steps[i].0, poses[i], steps[i].2.reversed) }
    }

    /// The pose an edge's actions start and end in: standing with hands on
    /// hips (top), hanging (bottom), peeking from behind the edge (sides).
    static func restPose(_ edge: FigureEdge) -> FigureJoints {
        switch edge {
        case .top: .rest
        case .bottom: FigureEdgePoses.hang
        case .leading, .trailing: FigureEdgePoses.peek
        }
    }

    /// Out of sight at `edge` after ducking to relocate.
    static func duckPose(_ edge: FigureEdge) -> FigureJoints {
        edge == .top ? FigureJoints.rest.with { $0.y = 64 + behind } : hiddenPose(.spring, edge: edge)
    }

    /// Run cycles played by `run` (≈ 2.6 s at tempo 1).
    static let runCycles = 4
    /// Keyframes per run cycle — enough that linear blends read as a curve.
    static let runSamplesPerCycle = 12

    /// Fully behind the card (or outside it, at a side), ready for `entrance`.
    static func hiddenPose(_ entrance: FigureEntrance, edge: FigureEdge = .top) -> FigureJoints {
        switch edge {
        case .bottom: return FigureEdgePoses.hangHidden
        case .leading, .trailing: return FigureEdgePoses.sideHidden
        case .top: break
        }
        return switch entrance {
        case .spring: FigureJoints.rest.with { $0.y = 64 + behind }
        case .climb: climbHang.with { $0.y = 78 + behind }
        }
    }

    /// Hanging behind the card by the hands: arms straight up, hands just
    /// just over the edge, the rest of the body hidden.
    private static let climbHang = FigureJoints.rest.with {
        $0.armL = -168; $0.elbowL = 0; $0.armR = 168; $0.elbowR = 0
        $0.legL = -3; $0.legR = 3; $0.y = 63 + behind
    }

    /// The climb after `hiddenPose(.climb)`: grab, hang, pull up (elbows out,
    /// hands stay on the edge), knee on the edge with arms pushing down,
    /// stand up with a small overshoot. 1.4 s at tempo 1.
    private static let climbSteps: [(Double, FigureJoints, Easing)] = {
        let rest = FigureJoints.rest
        let sag = climbHang.with { $0.y = 63.5 + behind; $0.tilt = 4 }
        let pulled = climbHang.with {
            $0.armL = -120; $0.elbowL = 187; $0.armR = 120; $0.elbowR = -187
            $0.legL = -8; $0.kneeL = 10; $0.legR = 6; $0.kneeR = -6; $0.y = 36 + behind
        }
        let knee = rest.with {
            $0.armL = -40; $0.elbowL = 0; $0.armR = 40; $0.elbowR = 0
            $0.legL = -105; $0.kneeL = 115; $0.legR = 4; $0.kneeR = 0
            $0.lean = -4; $0.y = 14 + behind; $0.tilt = -5
        }
        return [
            (0.22, climbHang, .out),
            (0.12, sag, .inOut),
            (0.38, pulled, .inOut),
            (0.28, knee, .inOut),
            (0.26, rest.with { $0.y = -2 }, .out),
            (0.14, rest, .inOut),
        ]
    }()

    /// 0…1 along the walk at `time` (eased; 0 before, 1 after); nil when the
    /// sequence doesn't walk.
    func walkProgress(at time: Double) -> Double? {
        guard let window = walkWindow else { return nil }
        let u = min(max((time - window.lowerBound) / max(window.upperBound - window.lowerBound, 1e-6), 0), 1)
        return Self.ease(u, .inOut)
    }

    /// The shortest still stretch worth stopping the clock for, seconds.
    static let minimumStill = 0.15

    /// Stretches where nothing moves (the same pose at both ends, no walk,
    /// no fade), merged when adjacent — the animation clock can stop there.
    var stillWindows: [ClosedRange<Double>] {
        guard !fadesIn else { return [] }
        var windows: [ClosedRange<Double>] = []
        for (a, b) in zip(keyframes, keyframes.dropFirst()) where a.joints == b.joints && b.time > a.time {
            if let walk = walkWindow, walk.overlaps(a.time...b.time), walk.upperBound > a.time, walk.lowerBound < b.time {
                continue
            }
            if let last = windows.last, abs(last.upperBound - a.time) < 1e-9 {
                windows[windows.count - 1] = last.lowerBound...b.time
            } else {
                windows.append(a.time...b.time)
            }
        }
        return windows.filter { $0.upperBound - $0.lowerBound >= Self.minimumStill }
    }

    /// The pose at `time` seconds from the start (clamped to the ends).
    func joints(at time: Double) -> FigureJoints {
        guard let first = keyframes.first else { return .rest }
        if time <= first.time { return first.joints }
        for (a, b) in zip(keyframes, keyframes.dropFirst()) where time <= b.time {
            let u = (time - a.time) / max(b.time - a.time, 1e-6)
            return a.joints.interpolated(to: b.joints, Self.ease(u, b.easing))
        }
        return final
    }

    /// Opacity at `time` — only the Reduce Motion entrance fades.
    func opacity(at time: Double) -> Double {
        fadesIn ? min(1, max(0, time / 0.2)) : 1
    }

    static func ease(_ u: Double, _ easing: Easing) -> Double {
        switch easing {
        case .inOut:
            return u * u * (3 - 2 * u)
        case .out:
            let c1 = 1.70158, c3 = c1 + 1
            return 1 + c3 * pow(u - 1, 3) + c1 * pow(u - 1, 2)
        case .in:
            return u * u * u
        case .linear:
            return u
        case .backIn:
            return 1 - ease(1 - u, .out)
        case .outCubic:
            return 1 - ease(1 - u, .in)
        }
    }
}

/// Joint positions of a pose in the 100×84 grid (the canvas's ground at y 84).
struct FigureSkeleton: Equatable, Sendable {
    static let gridSize = CGSize(width: 100, height: 84)
    /// The card's edge for the peeking figure: the standing feet (round caps
    /// included) end right on it.
    static let edgeY: CGFloat = 108
    /// What the peeking figure draws: the full width, from above the head
    /// (room for jumps and raised arms) down to the card's edge.
    static let peekBox = CGRect(x: 0, y: 0, width: gridSize.width, height: edgeY)
    static let torsoWidth: CGFloat = 12
    static let limbWidth: CGFloat = 8.5
    static let headRadius: CGFloat = 8.2

    var hip: CGPoint
    var torsoTop: CGPoint
    var head: CGPoint
    /// Shoulder → elbow → hand.
    var armL: [CGPoint]
    var armR: [CGPoint]
    /// Hip → knee → foot.
    var legL: [CGPoint]
    var legR: [CGPoint]

    init(_ p: FigureJoints) {
        func add(_ point: CGPoint, _ length: Double, _ degrees: Double) -> CGPoint {
            let r = degrees * .pi / 180
            return CGPoint(x: point.x + length * sin(r), y: point.y + length * cos(r))
        }
        let hip = CGPoint(x: 50 + p.x, y: 70 + p.y)
        let body = 180 - p.lean
        // In profile both shoulders and both hips sit on one point.
        let spread = 1 - min(max(p.profile, 0), 1)
        let shoulder = add(hip, 22, body)
        let shoulderL = add(shoulder, 5 * spread, body + 90)
        let shoulderR = add(shoulder, 5 * spread, body - 90)
        let elbowL = add(shoulderL, 15, p.armL - p.lean)
        let elbowR = add(shoulderR, 15, p.armR - p.lean)
        let hipL = CGPoint(x: hip.x - 2.5 * spread, y: hip.y)
        let hipR = CGPoint(x: hip.x + 2.5 * spread, y: hip.y)
        let kneeL = add(hipL, 17, p.legL)
        let kneeR = add(hipR, 17, p.legR)

        // Mirror around the hip for a figure facing left.
        func m(_ point: CGPoint) -> CGPoint {
            CGPoint(x: hip.x + (point.x - hip.x) * p.facing, y: point.y)
        }
        self.hip = hip
        self.torsoTop = m(add(hip, 24, body))
        self.head = m(add(hip, 40, 180 - p.lean - p.tilt))
        self.armL = [shoulderL, elbowL, add(elbowL, 14, p.armL + p.elbowL - p.lean)].map(m)
        self.armR = [shoulderR, elbowR, add(elbowR, 14, p.armR + p.elbowR - p.lean)].map(m)
        self.legL = [hipL, kneeL, add(kneeL, 17, p.legL + p.kneeL)].map(m)
        self.legR = [hipR, kneeR, add(kneeR, 17, p.legR + p.kneeR)].map(m)
        self.farLimbOpacity = 1 + (FigureJoints.farLimbOpacity - 1) * (1 - spread)
    }

    /// Opacity of the `L` arm and leg: 1 from the front, fading in profile.
    var farLimbOpacity: Double
}

/// Where along the card's top edge the figure stands — a fraction of the free
/// width (0 = leftmost, 1 = rightmost spot), so it doesn't always pop up in
/// the same place.
enum FigurePlacement {
    /// The smallest jump between two spots, as a fraction of the free width.
    static let minimumJump = 0.35

    /// A fresh spot for an entrance.
    static func random(using generator: inout some RandomNumberGenerator) -> Double {
        Double.random(in: 0...1, using: &generator)
    }

    /// A new spot at least `minimumJump` away from `current`.
    static func next(from current: Double, using generator: inout some RandomNumberGenerator) -> Double {
        let current = min(max(current, 0), 1)
        var candidates: [ClosedRange<Double>] = []
        if current - minimumJump >= 0 { candidates.append(0...(current - minimumJump)) }
        if current + minimumJump <= 1 { candidates.append((current + minimumJump)...1) }
        guard let range = candidates.randomElement(using: &generator) else { return current < 0.5 ? 1 : 0 }
        return Double.random(in: range, using: &generator)
    }

    /// Top of a side figure's box for `fraction` (0 = highest spot) along
    /// `track`, `margin` clear of both ends.
    static func sideTop(fraction: Double, track: ClosedRange<CGFloat>, boxHeight: CGFloat, margin: CGFloat) -> CGFloat {
        let free = max(0, track.upperBound - track.lowerBound - 2 * margin - boxHeight)
        return track.lowerBound + margin + free * CGFloat(min(max(fraction, 0), 1))
    }

    /// Trailing inset of the figure's box for `fraction` on a card `cardWidth`
    /// wide: between `margin` from the right and `margin` from the left edge.
    static func trailingInset(fraction: Double, cardWidth: CGFloat, figureWidth: CGFloat, margin: CGFloat) -> CGFloat {
        let free = max(0, cardWidth - 2 * margin - figureWidth)
        return margin + free * (1 - CGFloat(min(max(fraction, 0), 1)))
    }
}

/// The actions an edge plays, drawn at random each cycle.
enum FigureRepertoire {
    /// Actions on the top edge.
    static let top: [FigureAction] = [.wave, .jumpingJacks, .sideStretch, .march, .walk, .run]
    /// Actions hanging under the bottom edge.
    static let bottom: [FigureAction] = [.swing, .pullUp]
    /// Actions at a side edge.
    static let side: [FigureAction] = [.peek, .flag, .climb]

    /// The repertoire of `edge`.
    static func actions(for edge: FigureEdge) -> [FigureAction] {
        switch edge {
        case .top: top
        case .bottom: bottom
        case .leading, .trailing: side
        }
    }

    /// A random action from `actions`, never `previous` twice in a row
    /// (unless it is the only one).
    static func next(
        after previous: FigureAction?, from actions: [FigureAction] = top,
        using generator: inout some RandomNumberGenerator
    ) -> FigureAction {
        let fresh = actions.filter { $0 != previous }
        return (fresh.isEmpty ? actions : fresh).randomElement(using: &generator) ?? .rest
    }
}

/// The figure's footprint at each edge, in points — what an anchor needs.
struct FigureSizes: Equatable, Sendable {
    /// Height of the strip above a top edge.
    var figureHeight: CGFloat
    /// Smallest anchor width for the top and bottom (figure + both margins).
    var minWidth: CGFloat
    /// Height of the strip under a bottom edge.
    var hangHeight: CGFloat
    /// Smallest anchor height for a side (the side box + both margins).
    var sideMinHeight: CGFloat
}

/// Which marked view (`figureAnchor`) the figure comes out from behind next —
/// pure rules over frames in the stage's space.
enum FigureAnchorPicker {
    /// Room the card's edge needs above the bottom of the viewport.
    static let bottomClearance: CGFloat = 24

    /// The smallest anchor width that fits the figure between both margins.
    static func minimumWidth(figureWidth: CGFloat, margin: CGFloat) -> CGFloat {
        2 * margin + figureWidth
    }

    /// The figure fits on `rect`'s top edge and the whole of it shows:
    /// wide enough, horizontally inside `viewport`, the head below its top
    /// and the edge clear of its bottom. A nil viewport is unbounded.
    static func isEligible(rect: CGRect, viewport: CGRect?, figureHeight: CGFloat, minWidth: CGFloat) -> Bool {
        guard rect.width >= minWidth else { return false }
        guard let viewport else { return true }
        return rect.minX >= viewport.minX - 0.5
            && rect.maxX <= viewport.maxX + 0.5
            && rect.minY - figureHeight >= viewport.minY
            && rect.minY + bottomClearance <= viewport.maxY
    }

    /// The figure fits at `edge` of `rect` and the whole of it shows. Top as
    /// `isEligible(rect:viewport:figureHeight:minWidth:)`; bottom: wide enough,
    /// the edge on screen and the hang above the viewport's bottom; sides: tall
    /// enough, with that much of the card's height on screen.
    static func isEligible(rect: CGRect, edge: FigureEdge, viewport: CGRect?, sizes: FigureSizes) -> Bool {
        switch edge {
        case .top:
            return isEligible(
                rect: rect, viewport: viewport, figureHeight: sizes.figureHeight, minWidth: sizes.minWidth
            )
        case .bottom:
            guard rect.width >= sizes.minWidth else { return false }
            guard let viewport else { return true }
            return rect.minX >= viewport.minX - 0.5
                && rect.maxX <= viewport.maxX + 0.5
                && rect.maxY >= viewport.minY + bottomClearance
                && rect.maxY + sizes.hangHeight <= viewport.maxY
        case .leading, .trailing:
            guard rect.height >= sizes.sideMinHeight else { return false }
            guard let viewport else { return true }
            let track = sideTrack(rect: rect, viewport: viewport)
            return rect.minX >= viewport.minX - 0.5
                && rect.maxX <= viewport.maxX + 0.5
                && track.upperBound - track.lowerBound >= sizes.sideMinHeight
        }
    }

    /// The part of `rect`'s height a side figure may use: what is on screen.
    static func sideTrack(rect: CGRect, viewport: CGRect?) -> ClosedRange<CGFloat> {
        let top = max(rect.minY, viewport?.minY ?? rect.minY)
        let bottom = min(rect.maxY, viewport?.maxY ?? rect.maxY)
        return top...max(top, bottom)
    }

    /// Where the figure comes out next: a random eligible anchor other than
    /// `current` (the same one only when it is the only one), then an edge of
    /// it drawn by `FigureEdge.weight` among its allowed, eligible edges.
    /// nil when no anchor fits anywhere.
    static func nextPlacement<ID: Hashable>(
        current: ID?, candidates: [(id: ID, rect: CGRect, edges: FigureEdges)], viewport: CGRect?,
        sizes: FigureSizes, allowed: FigureEdges = .all, using generator: inout some RandomNumberGenerator
    ) -> (id: ID, edge: FigureEdge)? {
        let pairs = candidates.flatMap { candidate in
            FigureEdge.allCases
                .filter { candidate.edges.intersection(allowed).contains($0.member) }
                .filter { isEligible(rect: candidate.rect, edge: $0, viewport: viewport, sizes: sizes) }
                .map { (id: candidate.id, edge: $0) }
        }
        let others = pairs.filter { $0.id != current }
        let pool = others.isEmpty ? pairs : others
        let edges = FigureEdge.allCases.filter { edge in pool.contains { $0.edge == edge } }
        guard let edge = weightedEdge(edges, using: &generator) else { return nil }
        return pool.filter { $0.edge == edge }.randomElement(using: &generator)
    }

    /// One of `edges`, drawn by `FigureEdge.weight` (renormalized).
    static func weightedEdge(
        _ edges: [FigureEdge], using generator: inout some RandomNumberGenerator
    ) -> FigureEdge? {
        let total = edges.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total, using: &generator)
        for edge in edges {
            roll -= edge.weight
            if roll < 0 { return edge }
        }
        return edges.last
    }

    /// A random eligible anchor other than `current`; `current` only when it
    /// is the one eligible anchor; nil when none is.
    static func next<ID: Hashable>(
        current: ID?, candidates: [(id: ID, rect: CGRect)], viewport: CGRect?,
        figureHeight: CGFloat, minWidth: CGFloat, using generator: inout some RandomNumberGenerator
    ) -> ID? {
        let eligible = candidates.filter {
            isEligible(rect: $0.rect, viewport: viewport, figureHeight: figureHeight, minWidth: minWidth)
        }.map(\.id)
        let others = eligible.filter { $0 != current }
        return (others.isEmpty ? eligible : others).randomElement(using: &generator)
    }
}
