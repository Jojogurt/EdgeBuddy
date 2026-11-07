import CoreGraphics
import Foundation

/// What the peeking figure does after it steps onto the card's edge. The
/// stage draws one at random each cycle (`FigureRepertoire`).
enum FigureAction: CaseIterable, Equatable, Sendable {
    /// Hands on hips, a short nod — the resting state every action ends in.
    case rest
    /// A greeting.
    case wave
    case jumpingJacks
    /// A side bend.
    case sideStretch
    /// Marching in place: knees up, arms pumping.
    case march
    /// Turns sideways, lies down flat on the card's edge and inches along it
    /// like a caterpillar — hips up into an inverted V, hands reach forward,
    /// flat again — then gets back up (`FigureTimeline.walkDistance`).
    case wormWalk
    /// Cartwheels into a handstand on the card's edge, wobbles, comes back.
    case handstand
    /// Turns sideways and runs along the card's edge to another spot — the
    /// loader's run cycle (`FigureJoints.run(phase:)`), the same rig in profile.
    case run
    /// Bottom edge: swings on its hands like a pendulum, legs trailing.
    case swing
    /// Bottom edge: pulls itself up until the head reaches the edge.
    case pullUp
    /// Side edge: beside the card, a hand on its edge, hangs further out and
    /// looks around.
    case peek
    /// Side edge: a human flag — hands wide apart on the edge, the body held
    /// out flat beside the card.
    case flag
    /// Side edge: turns to the card and climbs up the outside of its edge
    /// hand over hand (`FigureTimeline.walkDistance`).
    case climb

    /// The action's name, as the stage and pins refer to it (`FigurePin.action`).
    var name: String { String(describing: self) }

    /// The action called `name`; nil = no such action.
    init?(name: String) {
        guard let action = Self.allCases.first(where: { $0.name == name }) else { return nil }
        self = action
    }
}

/// The stage's view of an edge (`FigureEdge` is public). Inside the stage
/// the sides are physical: leading = left (`FigureEdges.physical(for:)`).
extension FigureEdge {
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

    /// How often this edge is drawn among the allowed, visible ones:
    /// evenly, 25% each.
    var weight: Double { 0.25 }
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
        case .wave, .jumpingJacks, .march, .wormWalk: 2...4
        case .sideStretch: 1...2
        case .handstand: 1...3
        case .run: 3...5
        case .swing, .flag, .climb: 2...4
        case .pullUp, .peek: 1...3
        }
    }

    /// One looped cycle of `action`, leaving with `exit`.
    static func random(
        for action: FigureAction, exit: FigureEntrance, using generator: inout some RandomNumberGenerator
    ) -> FigureVariation {
        random(repeats: repeatRange(action), exit: exit, using: &generator)
    }

    /// One looped cycle of an action repeated within `repeats`, leaving with `exit`.
    static func random(
        repeats: ClosedRange<Int>, exit: FigureEntrance, using generator: inout some RandomNumberGenerator
    ) -> FigureVariation {
        FigureVariation(
            holdBefore: .random(in: holdBeforeRange, using: &generator),
            repeats: .random(in: repeats, using: &generator),
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

/// A hand or a foot of the rig: the end of a two-bone chain (upper arm and
/// forearm, thigh and shin).
enum FigureLimb: CaseIterable, Sendable {
    case armL, armR, legL, legR

    var isArm: Bool { self == .armL || self == .armR }

    /// Lengths of the chain's two bones, grid units.
    var bones: (upper: Double, lower: Double) {
        isArm
            ? (FigureSkeleton.upperArm, FigureSkeleton.forearm)
            : (FigureSkeleton.thigh, FigureSkeleton.shin)
    }
}

extension FigureJoints {
    /// The chain's first angle (upper arm, thigh) and its bend (elbow, knee).
    subscript(limb: FigureLimb) -> (angle: Double, bend: Double) {
        get {
            switch limb {
            case .armL: (armL, elbowL)
            case .armR: (armR, elbowR)
            case .legL: (legL, kneeL)
            case .legR: (legR, kneeR)
            }
        }
        set {
            switch limb {
            case .armL: (armL, elbowL) = newValue
            case .armR: (armR, elbowR) = newValue
            case .legL: (legL, kneeL) = newValue
            case .legR: (legR, kneeR) = newValue
            }
        }
    }

    /// A copy with `limb` re-solved by two-bone IK so its end (hand or foot,
    /// as drawn — `facing` included) sits on `target`; out of reach it
    /// straightens toward it. The bend keeps its current sign (the elbow or
    /// knee stays on its side) unless `side` picks one, and the angle stays within half a turn of the
    /// current one, so blends from here never swing the long way round.
    func placing(_ limb: FigureLimb, at target: CGPoint, bend side: Double? = nil) -> FigureJoints {
        // Mid-turn the figure is squashed to a line: nothing to solve.
        guard abs(facing) > 0.2 else { return self }
        let skeleton = FigureSkeleton(self)
        let hip = skeleton.hip
        // Solve before the facing mirror (around the hip).
        func unmirrored(_ point: CGPoint) -> CGPoint {
            CGPoint(x: hip.x + (point.x - hip.x) / facing, y: point.y)
        }
        let root = unmirrored(skeleton.chain(limb)[0])
        let goal = unmirrored(target)
        let dx = Double(goal.x - root.x), dy = Double(goal.y - root.y)
        let (upper, lower) = limb.bones
        let reach = min(max(hypot(dx, dy), abs(upper - lower) + 1e-6), upper + lower)
        func degrees(cosine: Double) -> Double { acos(min(max(cosine, -1), 1)) * 180 / .pi }
        let atRoot = degrees(cosine: (upper * upper + reach * reach - lower * lower) / (2 * upper * reach))
        let atJoint = degrees(cosine: (upper * upper + lower * lower - reach * reach) / (2 * upper * lower))
        let current = self[limb]
        let sign: Double = (side ?? current.bend) >= 0 ? 1 : -1
        // Arms turn with the torso (`FigureSkeleton`), legs don't.
        var angle = atan2(dx, dy) * 180 / .pi - sign * atRoot + (limb.isArm ? lean : 0)
        angle += 360 * ((current.angle - angle) / 360).rounded()
        var copy = self
        copy[limb] = (angle, sign * (180 - atJoint))
        return copy
    }

    /// The same drawing seen the other way round: `facing` negated, every
    /// angle negated and the `L` and `R` limbs swapped, so the figure looks
    /// exactly as before (from the front; in profile the faded far limbs
    /// swap). Lets a turn happen in front view without squashing it flat.
    var flippedFacing: FigureJoints {
        with {
            $0.armL = -armR; $0.elbowL = -elbowR; $0.armR = -armL; $0.elbowR = -elbowL
            $0.legL = -legR; $0.kneeL = -kneeR; $0.legR = -legL; $0.kneeR = -kneeL
            $0.lean = -lean; $0.tilt = -tilt; $0.facing = -facing
        }
    }

    /// A copy with each given hand or foot placed on its point (`placing(_:at:)`).
    func placing(
        armL l: CGPoint? = nil, armR r: CGPoint? = nil, legL fl: CGPoint? = nil, legR fr: CGPoint? = nil
    ) -> FigureJoints {
        [(FigureLimb.armL, l), (.armR, r), (.legL, fl), (.legR, fr)].reduce(self) { pose, item in
            item.1.map { pose.placing(item.0, at: $0) } ?? pose
        }
    }
}

/// How a hand or foot moves over a keyframe segment when it is placed
/// rather than swung by its joint angles (`LimbPaths`): along the straight
/// line between where it is at the segment's two ends, with the segment's
/// easing — so a grip stays put, or slides exactly as far as the figure
/// travels — lifted by `lift` half-way (a step or a reach).
struct LimbPath: Equatable, Sendable {
    /// Offset at the middle of the segment, grid units as drawn (fading in
    /// and out along a half sine); zero = it stays on its line.
    var lift = CGVector.zero
    /// The side the elbow or knee bends to (the sign of its bend); nil = as
    /// the blended pose has it.
    var bend: Double?

    /// A grip or a planted foot: on the line, no lift.
    static let held = LimbPath()

    /// Lifted by `dx`, `dy` half-way.
    static func lifted(_ dx: Double, _ dy: Double) -> LimbPath {
        LimbPath(lift: CGVector(dx: dx, dy: dy))
    }
}

/// The hands and feet a keyframe segment places (`FigureTimeline.Keyframe.limbs`);
/// nil = swung by the blended joint angles.
struct LimbPaths: Equatable, Sendable {
    var armL: LimbPath?
    var armR: LimbPath?
    var legL: LimbPath?
    var legR: LimbPath?

    /// Nothing placed.
    static let none = LimbPaths()
    /// Both hands keep their grips.
    static let hands = LimbPaths(armL: .held, armR: .held)
    /// Both feet stay planted.
    static let feet = LimbPaths(legL: .held, legR: .held)

    var isEmpty: Bool { self == .none }

    subscript(limb: FigureLimb) -> LimbPath? {
        switch limb {
        case .armL: armL
        case .armR: armR
        case .legL: legL
        case .legR: legR
        }
    }
}

/// Poses of the bottom and side edges (canvas `S_ludzik_krawedzie`, 1:1)
/// and the top edge's floor work (worm walk, handstand). Hands on an edge
/// are held by two-bone IK: solved once for the keyframes, and again while
/// sampling the segments between them (`LimbPaths`), so the grips stay put
/// while the body moves.
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
    /// Where the hanging hands hold the edge (`hang`'s hands).
    static let gripL = FigureSkeleton(hang).armL[2]
    static let gripR = FigureSkeleton(hang).armR[2]
    /// The hands on their grips with the elbows bent outward — a wide-grip
    /// pull-up seen from the front: the left elbow bends to the left (a
    /// negative bend), the right one to the right.
    private static func gripping(_ pose: FigureJoints) -> FigureJoints {
        pose.with { $0.elbowL = -1; $0.elbowR = 1 }.placing(armL: gripL, armR: gripR)
    }
    static let pullMid = gripping(rest.with {
        $0.armL = -165; $0.armR = 165
        $0.legL = -4; $0.kneeL = 8; $0.legR = 4; $0.kneeR = -8; $0.y = -4
    })
    /// Pulled up, the head at the edge, knees drawn up, elbows out.
    static let pullTop = gripping(rest.with {
        $0.armL = -155; $0.armR = 155
        $0.legL = -6; $0.kneeL = 18; $0.legR = 6; $0.kneeR = -18; $0.y = -8
    })
    /// Fully behind the card, above its bottom edge.
    static let hangHidden = pullTop.with { $0.y = -96 }
    /// The pendulum's ends: the body turns around the hands, legs lag.
    static let swingRight = gripping(rest.with {
        $0.armL = -172; $0.armR = 170
        $0.legL = 15; $0.kneeL = -8.4; $0.legR = 21; $0.kneeR = -8.4
        $0.lean = -11; $0.x = 9.2; $0.y = -2.9; $0.tilt = -3.3
    })
    static let swingLeft = gripping(rest.with {
        $0.armL = -170; $0.armR = 172
        $0.legL = -21; $0.kneeL = 8.4; $0.legR = -15; $0.kneeR = 8.4
        $0.lean = 11; $0.x = -9.2; $0.y = -2.9; $0.tilt = 3.3
    })
    /// Hands on the grips under the bottom edge, elbows bending outward
    /// whenever the arms bend (`gripping`).
    static let hangGrips = LimbPaths(armL: LimbPath(bend: -1), armR: LimbPath(bend: 1))

    // MARK: Side — drawn at the trailing edge (grid x `sideEdgeX`), card to the left

    /// The card's side edge in the rig's grid. The card hides the figure:
    /// everything left of the edge is behind it (only the hands wrapped on
    /// the edge show, `sideMaskX`); the figure plays right of it, outside.
    static let sideEdgeX = 100.0
    /// The vertical line the side grips sit on (hands wrapped on the edge).
    static let sideGripX = sideEdgeX - 2.5
    /// Where the drawn side box starts: the gripping hands' caps show, the
    /// rest of the card hides the figure.
    static let sideMaskX = sideGripX - Double(FigureSkeleton.limbWidth) / 2
    /// Where the peek's hand holds the edge.
    static let peekGrip = CGPoint(x: sideGripX, y: 52)

    /// Beside the card, outside its side edge: the near hand on the edge,
    /// elbow down, the other on the hip, leaning out a little, head turned
    /// to the card — the side's rest.
    static let peek = rest.with {
        $0.armL = -60; $0.elbowL = -60; $0.legL = -4; $0.legR = 6
        $0.lean = 6; $0.x = 66; $0.tilt = -8
    }.placing(armL: peekGrip)
    /// The side's nod.
    static let peekTilt = peek.with { $0.tilt = 6 }
    /// Hanging out from the edge on a longer arm, looking away from the card.
    static let peekOut = peek.with { $0.lean = 16; $0.x = 70; $0.tilt = 4 }.placing(armL: peekGrip)
    static let peekLook = peekOut.with { $0.tilt = -6 }
    /// Fully behind the card, left of its side edge (and of `sideMaskX`).
    static let sideHidden = peek.with { $0.x = 14 }

    /// Where the flag holds the edge: the upper hand high on a straight arm
    /// (pulling), the lower one well down on it (pushing).
    static let flagGripTop = CGPoint(x: sideGripX, y: 35)
    static let flagGripBottom = CGPoint(x: sideGripX, y: 76)
    /// The flag's body held out sideways from the edge: torso flat, head to
    /// the card, the upper shoulder (`R`) above the lower (`L`).
    private static let flagBody = rest.with {
        $0.armL = -140; $0.elbowL = -1; $0.armR = -220; $0.elbowR = 1
        $0.legL = 95; $0.legR = 85; $0.lean = -90; $0.x = 94; $0.y = -14
    }
    /// The flag: hands wide apart on the card's edge, the body straight out
    /// beside the card, legs scissoring between `flagA` and `flagB`. Past a
    /// card near the screen's edge it is cut there.
    static let flagA = flagBody.placing(armL: flagGripBottom, armR: flagGripTop)
    static let flagB = flagBody.with { $0.legL = 80; $0.legR = 100 }.placing(armL: flagGripBottom, armR: flagGripTop)
    /// Half-way from the peek into the flag: hands already on the flag's
    /// grips, body tilted 45°, knees bent.
    static let flagSwing = rest.with {
        $0.armL = -100; $0.elbowL = -1; $0.armR = -200; $0.elbowR = 1
        $0.legL = 40; $0.kneeL = -20; $0.legR = 20; $0.kneeR = -10
        $0.lean = -45; $0.x = 80; $0.y = -6; $0.tilt = 15
    }.placing(armL: flagGripBottom, armR: flagGripTop)

    /// How far the climb rises per half-cycle (one hand's pull), grid
    /// units: each hand and foot moves this much along the edge, so a held
    /// one stays put on the card while the figure travels.
    static let climbReach = 26.0
    /// The line the climbing feet press on: the card's edge.
    static let climbFootX = sideEdgeX - 0.5
    /// The high hand (`climbA`'s right) and the low foot, grid y.
    private static let climbHandTop = 26.0
    private static let climbFootBottom = 102.0
    /// Outside the card in profile, facing it: hip past the edge, elbows
    /// down, knees up toward the card.
    private static let climbBody = rest.with {
        $0.armL = 0; $0.elbowL = 60; $0.armR = 0; $0.elbowR = 60
        $0.legL = 0; $0.kneeL = -60; $0.legR = 0; $0.kneeR = -60
        $0.lean = 8; $0.x = 64; $0.y = 2; $0.profile = 1; $0.facing = -1
    }
    /// Climbing up the outside of the side edge, hand over hand: the right
    /// hand and the left foot high, the others a reach lower; `climbB` swaps them.
    static let climbA = climbBody.placing(
        armL: CGPoint(x: sideGripX, y: climbHandTop + climbReach), armR: CGPoint(x: sideGripX, y: climbHandTop),
        legL: CGPoint(x: climbFootX, y: climbFootBottom - climbReach), legR: CGPoint(x: climbFootX, y: climbFootBottom)
    )
    static let climbB = climbBody.placing(
        armL: CGPoint(x: sideGripX, y: climbHandTop), armR: CGPoint(x: sideGripX, y: climbHandTop + climbReach),
        legL: CGPoint(x: climbFootX, y: climbFootBottom), legR: CGPoint(x: climbFootX, y: climbFootBottom - climbReach)
    )
    /// How a side action that has its own way in and out (the climb, the
    /// flag) comes out from behind the card and goes back.
    struct Route: Sendable {
        /// Behind the card, ready to reach around the edge.
        let hidden: FigureJoints
        /// From `hidden` into `held`, hands first.
        let entrance: [FigureTimeline.Step]
        /// `entrance` backwards: the body swings in, the hands let go last.
        let exit: [FigureTimeline.Step]
        /// The action's own pose, kept while holding before and after it.
        let held: FigureJoints
    }

    /// The route of `action` at a side; nil = it comes out through the peek.
    static func route(for action: FigureAction) -> Route? {
        switch action {
        case .climb: climbRoute
        case .flag: flagRoute
        default: nil
        }
    }

    /// The route to leave by from `pose` mid-action (a tap): the climb's in
    /// profile, the flag's when the body is held out sideways; nil = duck.
    static func route(leaving pose: FigureJoints) -> Route? {
        if pose.profile > 0.5 { return climbRoute }
        if pose.lean < -30 { return flagRoute }
        return nil
    }

    static let climbRoute = Route(hidden: climbHidden, entrance: climbEntranceSteps, exit: climbExitSteps, held: climbA)

    /// Behind the card by its edge, upright, leaning toward it, arms down.
    static let flagHidden = rest.with {
        $0.armL = -10; $0.elbowL = -1; $0.armR = 10; $0.elbowR = 1
        $0.lean = 20; $0.tilt = -20; $0.x = 26; $0.y = 8
    }
    /// The upper hand around the edge first, on the flag's upper grip.
    static let flagReachHigh = flagHidden.placing(armR: flagGripTop)
    /// Then the lower hand, on the lower grip.
    static let flagReachLow = flagReachHigh.placing(armL: flagGripBottom)
    /// The flag's entrance from `flagHidden`: upper hand, lower hand, then
    /// the body swings out on them into `flagA`, legs trailing.
    static let flagEntranceSteps: [FigureTimeline.Step] = [
        .init(duration: 0.24, joints: flagReachHigh, easing: .out),
        .init(duration: 0.2, joints: flagReachLow, limbs: LimbPaths(armR: .held)),
        .init(duration: 0.34, joints: flagSwing, limbs: .hands),
        .init(duration: 0.3, joints: flagA, limbs: .hands),
    ]
    static let flagRoute = Route(
        hidden: flagHidden, entrance: flagEntranceSteps,
        exit: FigureTimeline.reversed(flagEntranceSteps, from: flagHidden), held: flagA
    )

    /// Where the climb's hands hold the edge in `climbA`.
    static let climbGripLow = CGPoint(x: sideGripX, y: climbHandTop + climbReach)
    static let climbGripHigh = CGPoint(x: sideGripX, y: climbHandTop)
    /// Behind the card, already turned to it as on the climb: `climbA`
    /// moved left until nothing shows past the edge.
    static let climbHidden = climbA.with { $0.x = 36 }
    /// The first hand around the edge: the low grip, the body still behind.
    static let climbReachLow = climbHidden.placing(armL: climbGripLow)
    /// Then the other hand higher up.
    static let climbReachHigh = climbReachLow.placing(armR: climbGripHigh)
    /// Swinging out on both hands, legs trailing, feet not on the edge yet.
    static let climbSwingOut = climbBody.with {
        $0.x = 52; $0.lean = 14; $0.legL = 20; $0.kneeL = -50; $0.legR = -5; $0.kneeR = -30
    }.placing(armL: climbGripLow, armR: climbGripHigh)
    /// The climb's entrance from `climbHidden`: one hand grips the edge,
    /// the other higher, the body swings out on them and the feet find the
    /// edge — `climbA`. Facing the card all the way (no turn).
    static let climbEntranceSteps: [FigureTimeline.Step] = [
        .init(duration: 0.24, joints: climbReachLow, easing: .out),
        .init(duration: 0.2, joints: climbReachHigh, limbs: LimbPaths(armL: .held)),
        .init(duration: 0.32, joints: climbSwingOut, limbs: .hands),
        .init(duration: 0.26, joints: climbA, limbs: .hands),
    ]
    /// The entrance backwards, from `climbA`: the body swings back in
    /// behind the card, then the hands let go, the upper one first.
    static let climbExitSteps: [FigureTimeline.Step] = FigureTimeline.reversed(climbEntranceSteps, from: climbHidden)
    /// From the peek to `climbA` without squashing the figure flat: the
    /// same peek seen the other way round (`flippedFacing`, an invisible
    /// switch), then a turn into profile; the edge hand slides up the edge
    /// to the high grip.
    static let climbTurnIn: [FigureTimeline.Step] = [
        .init(duration: 0, joints: peek.flippedFacing),
        .init(duration: 0.42, joints: climbA, limbs: LimbPaths(armR: .held)),
    ]
    /// Back from `climbA` to the peek, the same way.
    static let climbTurnOut: [FigureTimeline.Step] = [
        .init(duration: 0.42, joints: peek.flippedFacing, limbs: LimbPaths(armR: .held)),
        .init(duration: 0, joints: peek),
    ]

    /// From `climbA` to `climbB`: the high hand and foot hold on (sliding
    /// down the grid as the figure rises), the low ones reach up, off the edge.
    static let climbFromA = LimbPaths(armL: .lifted(5, 0), armR: .held, legL: .held, legR: .lifted(6, 0))
    /// From `climbB` back to `climbA`.
    static let climbFromB = LimbPaths(armL: .held, armR: .lifted(5, 0), legL: .lifted(6, 0), legR: .held)

    // MARK: Top — floor work on the card's top edge (grid y `FigureSkeleton.edgeY`)

    /// Where a hand or foot resting on the top edge sits: its round cap
    /// touches the edge.
    static let groundY = Double(FigureSkeleton.edgeY - FigureSkeleton.limbWidth / 2)

    /// How far one worm cycle carries the figure, grid units: the feet slide
    /// up this much to the hands, then the hands reach this much ahead.
    static let wormStride = 31.5
    /// Where the lying worm's hands and feet rest, grid x (facing right).
    private static let wormHandX = 90.0
    private static let wormFootX = 5.5
    /// In profile, facing right: the run's turn.
    private static let wormSide = rest.with {
        $0.armL = 60; $0.elbowL = -20; $0.armR = 60; $0.elbowR = -20
        $0.legL = -90; $0.kneeL = 5; $0.legR = -90; $0.kneeR = 5; $0.profile = 1
    }
    /// Kneeling sideways on the edge, sitting up, shins flat behind.
    static let wormKneel = wormSide.with {
        $0.armL = 10; $0.elbowL = -30; $0.armR = -5; $0.elbowR = -30
        $0.legL = 0; $0.kneeL = -90; $0.legR = 0; $0.kneeR = -90
        // Knees a hair above the edge: they stay clear of it while the legs stretch out.
        $0.lean = 8; $0.x = -6; $0.y = groundY - FigureSkeleton.thigh - 70 - 1
    }.placing(legL: wormKnees, legR: wormKnees)
    /// On hands and knees.
    static let wormCrawl = wormKneel.with { $0.lean = 66; $0.elbowL = -10; $0.elbowR = -10; $0.tilt = 0 }
        .placing(armL: CGPoint(x: 74, y: groundY), armR: CGPoint(x: 74, y: groundY))
    /// Shins on the edge behind the knees.
    private static var wormKnees: CGPoint { CGPoint(x: 44 - FigureSkeleton.thigh, y: groundY) }
    /// Lying flat on the edge, head up, arms reaching forward.
    static let wormFlat = wormSide.with { $0.kneeL = -5; $0.kneeR = -5; $0.lean = 90; $0.x = -10; $0.y = 32; $0.tilt = -14 }
        .placing(
            armL: CGPoint(x: wormHandX, y: groundY), armR: CGPoint(x: wormHandX, y: groundY),
            legL: CGPoint(x: wormFootX, y: groundY), legR: CGPoint(x: wormFootX, y: groundY)
        )
    /// The inverted V: hands where they were, feet a stride closer, hips up.
    static let wormArch = wormSide.with { $0.lean = 129; $0.x = 1; $0.y = 3; $0.tilt = -9 }
        .placing(
            armL: CGPoint(x: wormHandX, y: groundY), armR: CGPoint(x: wormHandX, y: groundY),
            legL: CGPoint(x: wormFootX + wormStride, y: groundY), legR: CGPoint(x: wormFootX + wormStride, y: groundY)
        )
    /// Standing to kneeling (and back): the feet step back along the edge.
    static let wormStepBack = LimbPaths(legL: .lifted(0, -5), legR: .lifted(0, -5))
    /// Hands and knees to lying flat (and back): the legs swing out behind,
    /// knees clear of the edge, the hands reach forward.
    static let wormStretch = LimbPaths(
        armL: .lifted(0, -5), armR: .lifted(0, -5), legL: .lifted(0, -20), legR: .lifted(0, -20)
    )
    /// Flat to the V: hands hold, feet hop up to them.
    static let wormToArch = LimbPaths(armL: .held, armR: .held, legL: .lifted(0, -4), legR: .lifted(0, -4))
    /// V to flat, travelling a stride: feet hold (sliding back in the grid as
    /// the figure moves on), hands lift and land a stride ahead.
    static let wormToFlat = LimbPaths(armL: .lifted(0, -6), armR: .lifted(0, -6), legL: .held, legR: .held)

    /// The handstand's grips on the top edge.
    private static let handstandGripL = CGPoint(x: 78, y: groundY)
    private static let handstandGripR = CGPoint(x: 62, y: groundY)
    /// Arms straight up, ready to go over.
    static let handstandReach = rest.with { $0.armL = -165; $0.elbowL = -10; $0.armR = 165; $0.elbowR = 10 }
    /// Half a cartwheel: torso flat to the right, hands down on the edge,
    /// the left foot still on it, the right leg swinging over.
    static let handstandCartwheel = rest.with {
        $0.armL = -250; $0.elbowL = -10; $0.armR = 72; $0.elbowR = -30
        $0.legL = -45; $0.kneeL = 10; $0.legR = -140; $0.kneeR = 0
        $0.lean = 90; $0.x = -5; $0.y = 13; $0.tilt = -10
    }.placing(armL: handstandGripL, armR: handstandGripR, legL: CGPoint(x: 18, y: groundY))
    /// Into the cartwheel and out of it: the left foot steps out along the
    /// edge, the right one leaves it straight for the air (and back).
    static let handstandLunge = LimbPaths(legL: .lifted(0, -6), legR: .held)
    /// Legs kicking over the top.
    static let handstandKick = rest.with {
        $0.armL = -200; $0.elbowL = -5; $0.armR = 120; $0.elbowR = -5
        $0.legL = -120; $0.legR = -165; $0.lean = 140; $0.x = 10; $0.y = -8
    }.placing(armL: handstandGripL, armR: handstandGripR)
    /// Upside down on straight arms over the grips, legs up, a little apart.
    static let handstand = rest.with {
        $0.armL = -174; $0.elbowL = -2; $0.armR = 174; $0.elbowR = 2
        $0.legL = -176; $0.legR = -184; $0.lean = 180; $0.x = 20; $0.y = -17
    }.placing(armL: handstandGripL, armR: handstandGripR)
    /// The balance wobble's two ends.
    static let handstandWobbleL = handstand.with { $0.lean = 175; $0.legL = -170; $0.legR = -181 }
        .placing(armL: handstandGripL, armR: handstandGripR)
    static let handstandWobbleR = handstand.with { $0.lean = 185; $0.legL = -179; $0.legR = -190 }
        .placing(armL: handstandGripL, armR: handstandGripR)
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
        /// Hands and feet the segment ending here places by IK instead of
        /// blending their angles (grips, planted feet, reaches).
        var limbs: LimbPaths = .none
        /// How far the figure travels along the edge over the segment ending
        /// here, grid units (`walkDistance`).
        var travel: Double = 0
    }

    /// One segment of a built-in sequence (an entrance, an exit): its length
    /// at tempo 1, the pose it ends in, its easing and the limbs it places.
    struct Step: Equatable, Sendable {
        var duration: Double
        var joints: FigureJoints
        var easing: Easing = .inOut
        var limbs: LimbPaths = .none
    }

    let keyframes: [Keyframe]
    /// Reduce Motion: the figure fades in (0.2 s) instead of moving.
    let fadesIn: Bool
    /// When the figure is fully hidden behind the card mid-sequence (it ducked
    /// to move elsewhere), the time to jump to the new spot; nil = it stays.
    let relocatesAt: Double?

    /// While the figure travels along the edge (the run, the worm walk, the
    /// climb), seconds from the start; nil = it stays put.
    let walkWindow: ClosedRange<Double>?

    /// How far the figure travels, grid units, when its limbs set the
    /// distance (keyframe `travel`: the worm walk, the climb) — the stage
    /// moves it exactly this far so held hands and feet don't skate; nil =
    /// the stage picks the target (the run).
    let walkDistance: Double?

    /// Set when the sequence ends hidden behind the card (`FigureVariation.exit`):
    /// how long it stays there before the next cycle, seconds.
    let hiddenPause: Double?

    /// The action's signature frame, seconds from the start: where a pinned
    /// figure (`FigurePin`) freezes — the arm up of the wave, the balance of
    /// the handstand, the flag held out. nil under Reduce Motion (it only
    /// stands) and for the travelling actions (the climb, the worm walk, the
    /// run).
    let holdTime: Double?

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
    ///   - previousPose: the pose it ducks from when relocating (default the
    ///     previous edge's rest); mid-climb or mid-flag at a side it leaves
    ///     the way that action does (`FigureEdgePoses.route(leaving:)`).
    ///   - tempo: playback speed (`FigureStyle.tempo`); every time scales by 1/tempo.
    ///   - variation: holds, repeat count and exit of a looped cycle.
    init(
        action: FigureAction, entrance: FigureEntrance?, reduceMotion: Bool, edge: FigureEdge = .top,
        relocating: Bool = false, from previousEdge: FigureEdge? = nil, pose previousPose: FigureJoints? = nil,
        tempo: Double = 1, variation: FigureVariation = .standard
    ) {
        let pace = max(tempo * variation.tempoScale, 0.1)
        var frames: [Keyframe] = []
        var time = 0.0
        func at(
            _ dt: Double, _ joints: FigureJoints, _ easing: Easing = .inOut,
            limbs: LimbPaths = .none, travel: Double = 0
        ) {
            time += dt / pace
            frames.append(Keyframe(time: time, joints: joints, easing: easing, limbs: limbs, travel: travel))
        }
        func play(_ steps: [Step]) {
            for step in steps { at(step.duration, step.joints, step.easing, limbs: step.limbs) }
        }
        let rest = Self.restPose(edge)
        let poses = FigureEdgePoses.self
        let repeats = variation.repeats ?? Self.canvasRepeats(action)
        var walk: ClosedRange<Double>?
        var signature: Double?

        if reduceMotion {
            frames.append(Keyframe(time: 0, joints: rest, easing: .inOut))
            // A fixed crossfade, independent of tempo.
            frames.append(Keyframe(time: entrance != nil ? 0.2 : 0.01, joints: rest, easing: .inOut))
            keyframes = frames
            fadesIn = entrance != nil
            relocatesAt = nil
            walkWindow = nil
            walkDistance = nil
            hiddenPause = nil
            holdTime = nil
            return
        }

        let comesOut = relocating ? (entrance ?? .spring) : entrance
        // The side climb and flag come out and go back their own way, hands
        // first, straight into (and out of) the action — no peek, no turn.
        let route = edge.isSide ? poses.route(for: action) : nil
        let entersOwnWay = route != nil && comesOut != nil
        let leavesOwnWay = route != nil && variation.exit != nil
        let hidden = comesOut.map { route?.hidden ?? Self.hiddenPose($0, edge: edge) } ?? rest
        func hold(_ seconds: Double, _ pose: FigureJoints) {
            guard seconds > 0 else { return }
            time += seconds
            frames.append(Keyframe(time: time, joints: pose, easing: .inOut))
        }
        if relocating {
            let before = previousEdge ?? edge
            let start = previousPose ?? Self.restPose(before)
            frames.append(Keyframe(time: 0, joints: start, easing: .inOut))
            if before.isSide, let leaving = poses.route(leaving: start) {
                // Mid-climb or mid-flag: back around the edge, hands last —
                // quicker than the action's own exit.
                for step in leaving.exit { at(step.duration * 0.6, step.joints, step.easing, limbs: step.limbs) }
            } else {
                at(Self.duckDuration, Self.duckPose(before), .in, limbs: before == .bottom ? FigureEdgePoses.hangGrips : .none)
            }
            relocatesAt = time
            // Jump straight to the new edge's hidden pose: poses of one edge
            // may show at another.
            frames.append(Keyframe(time: time, joints: hidden, easing: .inOut))
            at(0.12, hidden)
        } else {
            frames.append(Keyframe(time: 0, joints: hidden, easing: .inOut))
            relocatesAt = nil
        }
        if let comesOut { play(route.map { entersOwnWay ? $0.entrance : [] } ?? Self.entranceSteps(comesOut, edge: edge)) }
        hold(variation.holdBefore, entersOwnWay ? route?.held ?? rest : rest)

        switch action {
        case .rest:
            for _ in 0..<repeats {
                switch edge {
                case .top:
                    at(0.2, rest.with { $0.tilt = 9 })
                    at(0.28, rest)
                case .bottom:
                    at(0.2, poses.hangSag, limbs: poses.hangGrips)
                    at(0.28, rest, limbs: poses.hangGrips)
                case .leading, .trailing:
                    at(0.24, poses.peekTilt, limbs: Self.peekGrip)
                    at(0.3, rest, limbs: Self.peekGrip)
                }
            }
            signature = time
        case .swing:
            at(0.42, poses.swingRight, limbs: poses.hangGrips)
            for round in 0..<repeats {
                at(0.56, poses.swingLeft, limbs: poses.hangGrips)
                if round == 0 { signature = time }
                at(0.56, poses.swingRight, limbs: poses.hangGrips)
            }
            at(0.5, rest, limbs: poses.hangGrips)
        case .pullUp:
            for round in 0..<repeats {
                at(0.3, poses.pullMid, limbs: poses.hangGrips)
                at(0.16, poses.pullTop, limbs: poses.hangGrips)
                if round == 0 { signature = time }
                at(0.14, poses.pullTop, limbs: poses.hangGrips)
                at(0.42, rest, limbs: poses.hangGrips)
            }
        case .peek:
            for round in 0..<repeats {
                at(0.35, poses.peekOut, limbs: Self.peekGrip)
                if round == 0 { signature = time }
                at(0.3, poses.peekLook, limbs: Self.peekGrip)
                at(0.25, poses.peekOut, limbs: Self.peekGrip)
                at(0.35, rest, limbs: Self.peekGrip)
            }
            at(0.24, poses.peekTilt, limbs: Self.peekGrip)
            at(0.3, rest, limbs: Self.peekGrip)
        case .flag:
            if !entersOwnWay {
                // From the peek: the near hand slides down the edge to its
                // grip, the other reaches up to the upper one; both hold
                // while the body swings out flat.
                at(0.4, poses.flagSwing, limbs: .hands)
                at(0.35, poses.flagA, limbs: .hands)
            }
            signature = time
            for _ in 0..<repeats {
                at(0.22, poses.flagB, limbs: .hands)
                at(0.22, poses.flagA, limbs: .hands)
            }
            if !leavesOwnWay {
                at(0.35, poses.flagSwing, limbs: .hands)
                at(0.42, rest, limbs: .hands)
            }
        case .climb:
            // Out already (the climb's own entrance), or turn from the peek
            // to the card; climb hand over hand (each half-cycle rises one
            // reach); leave the climb's own way (the exit), or turn back.
            if !entersOwnWay { play(poses.climbTurnIn) }
            for _ in 0..<repeats {
                at(0.36, poses.climbB, limbs: poses.climbFromA, travel: poses.climbReach)
                at(0.36, poses.climbA, limbs: poses.climbFromB, travel: poses.climbReach)
            }
            if !leavesOwnWay { play(poses.climbTurnOut) }
        case .wave:
            let up = rest.with {
                $0.armL = -8; $0.elbowL = 4; $0.armR = 148; $0.elbowR = -18; $0.tilt = -7
            }
            at(0.3, up)
            signature = time
            for _ in 0..<repeats {
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
            for round in 0..<repeats {
                at(0.15, air)
                at(0.15, open)
                if round == 0 { signature = time }
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
            for round in 0..<repeats {
                if round > 0 { at(0.45, up) }
                at(0.55, toLeft)
                if round == 0 { signature = time }
                at(0.45, toLeft)
                at(0.45, up)
                at(0.55, toRight)
                at(0.45, toRight)
            }
            at(0.4, up)
            at(0.42, rest)
        case .march:
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
            for round in 0..<repeats {
                at(0.22, leftUp)
                if round == 0 { signature = time }
                at(0.18, neutral)
                at(0.22, rightUp)
                at(0.18, neutral)
            }
            at(0.3, rest)
        case .wormWalk:
            // Turn sideways and kneel, hands down, lie flat; then per cycle
            // the feet hop up to the hands (hips up) and the hands reach a
            // stride ahead (flat again) — only that half travels. Push up
            // onto hands and knees, kneel, stand.
            at(0.4, poses.wormKneel, limbs: poses.wormStepBack)
            at(0.3, poses.wormCrawl, limbs: .feet)
            at(0.4, poses.wormFlat, limbs: poses.wormStretch)
            for _ in 0..<repeats {
                at(0.38, poses.wormArch, limbs: poses.wormToArch)
                at(0.38, poses.wormFlat, limbs: poses.wormToFlat, travel: poses.wormStride)
            }
            at(0.4, poses.wormCrawl, limbs: poses.wormStretch)
            at(0.3, poses.wormKneel, limbs: .feet)
            at(0.4, rest, limbs: poses.wormStepBack)
        case .handstand:
            // Arms up, half a cartwheel onto the hands, legs over into the
            // handstand, wobble, and the same way back.
            at(0.3, poses.handstandReach)
            at(0.36, poses.handstandCartwheel, limbs: poses.handstandLunge)
            at(0.3, poses.handstandKick, limbs: .hands)
            at(0.3, poses.handstand, limbs: .hands)
            signature = time
            for _ in 0..<repeats {
                at(0.32, poses.handstandWobbleL, limbs: .hands)
                at(0.32, poses.handstandWobbleR, limbs: .hands)
            }
            at(0.3, poses.handstand, limbs: .hands)
            at(0.3, poses.handstandKick, limbs: .hands)
            at(0.3, poses.handstandCartwheel, limbs: .hands)
            at(0.36, poses.handstandReach, limbs: poses.handstandLunge)
            at(0.36, rest)
        case .run:
            // Turn sideways into the first stride, run `runCycles` cycles
            // (sampled densely, linear in between), turn back to the front.
            at(0.22, Self.run(phase: 0))
            let runStart = time
            let samples = Self.runSamplesPerCycle
            for i in 1...(repeats * samples) {
                at(FigureJoints.runCycle / Double(samples), Self.run(phase: Double(i) / Double(samples)), .linear)
            }
            walk = runStart...time
            at(0.3, rest)
        }
        if let exit = variation.exit {
            hold(variation.holdAfter, leavesOwnWay ? route?.held ?? rest : rest)
            play(leavesOwnWay ? route?.exit ?? [] : Self.exitSteps(exit, edge: edge))
            hiddenPause = variation.hiddenPause
        } else {
            hiddenPause = nil
        }
        keyframes = frames
        fadesIn = false
        // Travel set by the limbs: the window spans its segments.
        let travelled = frames.indices.filter { frames[$0].travel > 0 }
        if let first = travelled.first, let last = travelled.last, first > 0 {
            walk = frames[first - 1].time...frames[last].time
            walkDistance = travelled.reduce(0) { $0 + frames[$1].travel }
        } else {
            walkDistance = nil
        }
        walkWindow = walk
        holdTime = signature
    }

    /// The peek's hand on the card's edge holds on (`FigureEdgePoses.peek`).
    private static let peekGrip = LimbPaths(armL: .held)

    /// Repetitions of an action's beat at the canvas count (`FigureVariation.repeats` nil).
    static func canvasRepeats(_ action: FigureAction) -> Int {
        switch action {
        case .rest, .sideStretch: 1
        case .swing, .pullUp, .peek, .handstand: 2
        case .wave, .jumpingJacks, .march, .flag, .climb, .wormWalk: 3
        case .run: runCycles
        }
    }

    /// How far `action` carries the figure along the edge with `repeats`
    /// beats, grid units — for the actions whose limbs set it (`walkDistance`);
    /// nil for the rest.
    static func travel(_ action: FigureAction, repeats: Int) -> Double? {
        switch action {
        case .climb: 2 * FigureEdgePoses.climbReach * Double(repeats)
        case .wormWalk: FigureEdgePoses.wormStride * Double(repeats)
        default: nil
        }
    }

    /// The shortest travel `action` needs (`travel` at the fewest repeats
    /// `FigureVariation.repeatRange` allows); nil when it stays put.
    static func minimumTravel(_ action: FigureAction) -> Double? {
        travel(action, repeats: FigureVariation.repeatRange(action).lowerBound)
    }

    /// The steps from `hiddenPose(entrance, edge:)` up to the edge's rest.
    /// Only the top uses `entrance`: the bottom lowers itself from behind the
    /// card on bent arms (hands sliding down the grip line) and straightens
    /// into the hang; a side slides out from behind the card's edge.
    static func entranceSteps(_ entrance: FigureEntrance, edge: FigureEdge = .top) -> [Step] {
        let poses = FigureEdgePoses.self
        switch edge {
        case .bottom:
            return [
                Step(duration: 0.5, joints: poses.pullTop, limbs: poses.hangGrips),
                Step(duration: 0.32, joints: poses.hang, limbs: poses.hangGrips),
                Step(duration: 0.14, joints: poses.hangSag, limbs: poses.hangGrips),
                Step(duration: 0.18, joints: poses.hang, limbs: poses.hangGrips),
            ]
        case .leading, .trailing:
            return [Step(duration: 0.42, joints: poses.peek, easing: .out), Step(duration: 0.14, joints: poses.peek)]
        case .top:
            break
        }
        let rest = FigureJoints.rest
        switch entrance {
        case .spring:
            return [
                Step(duration: 0.36, joints: rest.with { $0.y = -3 }, easing: .out),
                Step(duration: 0.16, joints: rest), Step(duration: 0.14, joints: rest),
            ]
        case .climb:
            return climbSteps
        }
    }

    /// The entrance played backwards: from rest down to `hiddenPose(entrance)`,
    /// each segment with the same length, limbs and the reversed easing.
    static func exitSteps(_ entrance: FigureEntrance, edge: FigureEdge = .top) -> [Step] {
        reversed(entranceSteps(entrance, edge: edge), from: hiddenPose(entrance, edge: edge))
    }

    /// `steps` (which start at `start`) played backwards, ending at `start`:
    /// each segment with the same length, limbs and the reversed easing.
    static func reversed(_ steps: [Step], from start: FigureJoints) -> [Step] {
        let poses = [start] + steps.map(\.joints)
        return steps.indices.reversed().map { i in
            Step(duration: steps[i].duration, joints: poses[i], easing: steps[i].easing.reversed, limbs: steps[i].limbs)
        }
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

    /// Fully behind the card, ready for `entrance`.
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
    private static let climbSteps: [Step] = {
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
            Step(duration: 0.22, joints: climbHang, easing: .out),
            Step(duration: 0.12, joints: sag),
            Step(duration: 0.38, joints: pulled),
            Step(duration: 0.28, joints: knee),
            Step(duration: 0.26, joints: rest.with { $0.y = -2 }, easing: .out),
            Step(duration: 0.14, joints: rest),
        ]
    }()

    /// 0…1 along the walk at `time` (0 before, 1 after); nil when the
    /// sequence doesn't walk. With `walkDistance` it follows the travelling
    /// segments and their easings (in step with the held limbs), else one
    /// eased glide over `walkWindow`.
    func walkProgress(at time: Double) -> Double? {
        guard let window = walkWindow else { return nil }
        if let distance = walkDistance, distance > 0 {
            var travelled = 0.0
            for (a, b) in zip(keyframes, keyframes.dropFirst()) where b.travel > 0 {
                if time >= b.time {
                    travelled += b.travel
                } else if time > a.time {
                    travelled += b.travel * Self.ease((time - a.time) / max(b.time - a.time, 1e-6), b.easing)
                }
            }
            return travelled / distance
        }
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
            let progress = Self.ease(u, b.easing)
            let pose = a.joints.interpolated(to: b.joints, progress)
            // Keyframes themselves are exact; between them the placed limbs
            // are re-solved so grips hold.
            guard !b.limbs.isEmpty, u > 0, u < 1, a.joints != b.joints else { return pose }
            return Self.placingLimbs(pose, paths: b.limbs, from: a.joints, to: b.joints, progress: progress, u: u)
        }
        return final
    }

    /// `pose` with each limb in `paths` re-solved onto its path: the straight
    /// line from where it is in `start` to where it is in `end`, at
    /// `progress` (the segment's eased time), lifted by `lift · sin(π·u)`.
    static func placingLimbs(
        _ pose: FigureJoints, paths: LimbPaths, from start: FigureJoints, to end: FigureJoints,
        progress: Double, u: Double
    ) -> FigureJoints {
        let first = FigureSkeleton(start), last = FigureSkeleton(end)
        let arc = sin(.pi * u)
        return FigureLimb.allCases.reduce(pose) { pose, limb in
            guard let path = paths[limb] else { return pose }
            let a = first.end(of: limb), b = last.end(of: limb)
            let target = CGPoint(
                x: a.x + (b.x - a.x) * progress + path.lift.dx * arc,
                y: a.y + (b.y - a.y) * progress + path.lift.dy * arc
            )
            return pose.placing(limb, at: target, bend: path.bend)
        }
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
    /// Bone lengths, grid units.
    static let upperArm = 15.0
    static let forearm = 14.0
    static let thigh = 17.0
    static let shin = 17.0

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
        let elbowL = add(shoulderL, Self.upperArm, p.armL - p.lean)
        let elbowR = add(shoulderR, Self.upperArm, p.armR - p.lean)
        let hipL = CGPoint(x: hip.x - 2.5 * spread, y: hip.y)
        let hipR = CGPoint(x: hip.x + 2.5 * spread, y: hip.y)
        let kneeL = add(hipL, Self.thigh, p.legL)
        let kneeR = add(hipR, Self.thigh, p.legR)

        // Mirror around the hip for a figure facing left.
        func m(_ point: CGPoint) -> CGPoint {
            CGPoint(x: hip.x + (point.x - hip.x) * p.facing, y: point.y)
        }
        self.hip = hip
        self.torsoTop = m(add(hip, 24, body))
        self.head = m(add(hip, 40, 180 - p.lean - p.tilt))
        self.armL = [shoulderL, elbowL, add(elbowL, Self.forearm, p.armL + p.elbowL - p.lean)].map(m)
        self.armR = [shoulderR, elbowR, add(elbowR, Self.forearm, p.armR + p.elbowR - p.lean)].map(m)
        self.legL = [hipL, kneeL, add(kneeL, Self.shin, p.legL + p.kneeL)].map(m)
        self.legR = [hipR, kneeR, add(kneeR, Self.shin, p.legR + p.kneeR)].map(m)
        self.farLimbOpacity = 1 + (FigureJoints.farLimbOpacity - 1) * (1 - spread)
    }

    /// Shoulder → elbow → hand or hip → knee → foot of `limb`.
    func chain(_ limb: FigureLimb) -> [CGPoint] {
        switch limb {
        case .armL: armL
        case .armR: armR
        case .legL: legL
        case .legR: legR
        }
    }

    /// The hand or foot of `limb`.
    func end(of limb: FigureLimb) -> CGPoint { chain(limb)[2] }

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

    /// Where a walk of `distance` grid units from `spot` ends: up a side
    /// (`direction` -1, toward smaller fractions) or along the top (+1 =
    /// right), at `scale` points per grid unit on an edge whose spots 0…1
    /// span `span` points (`PeekingFigureMetrics.travelSpan`).
    static func travelTarget(
        from spot: Double, distance: Double, direction: Double, scale: CGFloat, span: CGFloat
    ) -> Double {
        let fraction = distance * Double(scale) / max(Double(span), 1)
        return min(max(spot + direction * fraction, 0), 1)
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
    static let top: [FigureAction] = [.wave, .jumpingJacks, .sideStretch, .march, .wormWalk, .handstand, .run]
    /// Actions hanging under the bottom edge.
    static let bottom: [FigureAction] = [.swing, .pullUp]
    /// Actions at a side edge (the peek stays out: it only leans in place).
    static let side: [FigureAction] = [.flag, .climb]

    /// The repertoire of `edge`.
    static func actions(for edge: FigureEdge) -> [FigureAction] {
        switch edge {
        case .top: top
        case .bottom: bottom
        case .leading, .trailing: side
        }
    }

    /// Actions at a side at the screen's edge: no room beside the card to
    /// hang out or hold a flag, only to climb.
    static let screenEdgeSide: [FigureAction] = [.climb]

    /// The repertoire of `edge` with room to travel `room` grid units along
    /// it: actions whose limbs need more (`FigureTimeline.minimumTravel` —
    /// the climb on a short side, the worm walk on a narrow card) drop out.
    /// A side `atScreenEdge` only climbs (`screenEdgeSide`).
    static func actions(for edge: FigureEdge, room: Double, atScreenEdge: Bool = false) -> [FigureAction] {
        let all = edge.isSide && atScreenEdge ? screenEdgeSide : actions(for: edge)
        return all.filter { (FigureTimeline.minimumTravel($0) ?? 0) <= room + 1e-9 }
    }

    /// A random action from `actions`, never `previous` twice in a row
    /// (unless it is the only one).
    static func next(
        after previous: FigureAction?, from actions: [FigureAction] = top,
        using generator: inout some RandomNumberGenerator
    ) -> FigureAction {
        next(after: previous, from: actions, fallback: .rest, using: &generator)
    }

    /// A random one of `actions` (of any character), never `previous` twice
    /// in a row unless it is the only one; `fallback` when there are none.
    static func next<Action: Equatable>(
        after previous: Action?, from actions: [Action], fallback: Action,
        using generator: inout some RandomNumberGenerator
    ) -> Action {
        let fresh = actions.filter { $0 != previous }
        return (fresh.isEmpty ? actions : fresh).randomElement(using: &generator) ?? fallback
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
    /// Smallest on-screen height of a side for the climb: `sideMinHeight`
    /// plus its shortest climb (`FigureTimeline.minimumTravel(.climb)`).
    /// Shorter sides still take the peek and the flag.
    var climbMinHeight: CGFloat = 0
    /// A side closer than this to the viewport's edge is at the screen's
    /// edge: no room beside the card, so it only climbs there
    /// (`FigureAnchorPicker.isAtScreenEdge`).
    var screenEdgeGap: CGFloat = 0
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
    /// enough, with that much of the card's height on screen and the side
    /// edge itself on screen — at the screen's edge (`isAtScreenEdge`, it
    /// only climbs there) tall enough on screen for the climb.
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
            // The figure stands beside the card: the edge itself must be on
            // screen (the figure past it may be cut by the screen's edge).
            let x = edge == .trailing ? rect.maxX : rect.minX
            let track = sideTrack(rect: rect, viewport: viewport)
            let needed = isAtScreenEdge(rect: rect, edge: edge, viewport: viewport, gap: sizes.screenEdgeGap)
                ? max(sizes.sideMinHeight, sizes.climbMinHeight)
                : sizes.sideMinHeight
            return x >= viewport.minX - 0.5
                && x <= viewport.maxX + 0.5
                && track.upperBound - track.lowerBound >= needed
        }
    }

    /// `edge` of `rect` is a side less than `gap` from the viewport's edge
    /// on that side — no room beside the card. Never for top and bottom, or
    /// without a viewport (a single card).
    static func isAtScreenEdge(rect: CGRect, edge: FigureEdge, viewport: CGRect?, gap: CGFloat) -> Bool {
        guard let viewport else { return false }
        switch edge {
        case .top, .bottom: return false
        case .trailing: return viewport.maxX - rect.maxX < gap
        case .leading: return rect.minX - viewport.minX < gap
        }
    }

    /// The part of `rect`'s height a side figure may use: what is on screen.
    static func sideTrack(rect: CGRect, viewport: CGRect?) -> ClosedRange<CGFloat> {
        let top = max(rect.minY, viewport?.minY ?? rect.minY)
        let bottom = min(rect.maxY, viewport?.maxY ?? rect.maxY)
        return top...max(top, bottom)
    }

    /// Where the figure comes out next, among the allowed, eligible edges of
    /// the anchors, preferring in turn: a place that `offersFresh` (it can
    /// play something other than the last action — nil = any), another
    /// anchor than `current`, another edge than `currentEdge` of the same
    /// anchor. Among what is left an edge is drawn by `FigureEdge.weight`,
    /// then an anchor with it. `viewportFor` narrows the visible area per anchor
    /// (the scroll view it sits in); nil = `viewport` for all. nil when no
    /// anchor fits anywhere.
    static func nextPlacement<ID: Hashable>(
        current: ID?, currentEdge: FigureEdge? = nil,
        candidates: [(id: ID, rect: CGRect, edges: FigureEdges)], viewport: CGRect?,
        viewportFor: ((ID) -> CGRect?)? = nil,
        sizes: FigureSizes, allowed: FigureEdges = .all,
        offersFresh: ((_ id: ID, _ rect: CGRect, _ edge: FigureEdge) -> Bool)? = nil,
        using generator: inout some RandomNumberGenerator
    ) -> (id: ID, edge: FigureEdge)? {
        let pairs = candidates.flatMap { candidate in
            FigureEdge.allCases
                .filter { candidate.edges.intersection(allowed).contains($0.member) }
                .filter {
                    isEligible(
                        rect: candidate.rect, edge: $0, viewport: viewportFor?(candidate.id) ?? viewport, sizes: sizes
                    )
                }
                .map { (id: candidate.id, rect: candidate.rect, edge: $0) }
        }
        func preferring(
            _ pool: [(id: ID, rect: CGRect, edge: FigureEdge)],
            _ keep: ((id: ID, rect: CGRect, edge: FigureEdge)) -> Bool
        ) -> [(id: ID, rect: CGRect, edge: FigureEdge)] {
            let kept = pool.filter(keep)
            return kept.isEmpty ? pool : kept
        }
        var pool = preferring(pairs) { offersFresh?($0.id, $0.rect, $0.edge) ?? true }
        pool = preferring(pool) { $0.id != current }
        pool = preferring(pool) { $0.id != current || $0.edge != currentEdge }
        let edges = FigureEdge.allCases.filter { edge in pool.contains { $0.edge == edge } }
        guard let edge = weightedEdge(edges, using: &generator) else { return nil }
        return pool.filter { $0.edge == edge }.randomElement(using: &generator).map { (id: $0.id, edge: $0.edge) }
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
