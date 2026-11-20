import CoreGraphics
import Foundation

/// The champagne bottle in the figure's `R` hand (`FigureJoints.bottle`):
/// held around its body, the neck pointing along `bottleAngle`, grown in
/// and shrunk away around the hand by `bottle`.
struct FigureBottle: Equatable, Sendable {
    /// The hand that holds it.
    var hand: CGPoint
    /// Unit vector from the base to the neck, as drawn (`facing` included).
    var axis: CGVector
    /// Its size, 0…1 (`FigureJoints.bottle`; a little more while it pops in).
    var scale: Double

    /// Distance from the hand to the base and to the mouth, grid units.
    static let base = 5.5
    static let mouth = 14.5
    /// Half-widths of the body and the neck.
    static let body = 3.5
    static let neck = 1.5

    /// The bottle in `joints`; nil when it is not shown.
    init?(_ joints: FigureJoints, skeleton: FigureSkeleton) {
        guard joints.bottle > 0.01 else { return nil }
        let radians = joints.bottleAngle * .pi / 180
        // Mirrored around the hip like the skeleton.
        let dx = sin(radians) * (joints.facing < 0 ? -1 : 1), dy = cos(radians)
        hand = skeleton.end(of: .armR)
        axis = CGVector(dx: dx, dy: dy)
        scale = joints.bottle
    }

    /// The point `along` the axis from the hand, `across` it (+ = to the
    /// axis's right), both scaled.
    func point(along: Double, across: Double) -> CGPoint {
        CGPoint(
            x: hand.x + (axis.dx * along - axis.dy * across) * scale,
            y: hand.y + (axis.dy * along + axis.dx * across) * scale
        )
    }

    /// The mouth, where the spray comes out.
    var tip: CGPoint { point(along: Self.mouth, across: 0) }

    /// The outline: a flat base, the body, the shoulders narrowing into the
    /// neck, a lip at the mouth.
    var outline: [CGPoint] {
        let side: [(Double, Double)] = [
            (-Self.base, Self.body - 0.6), (-Self.base + 0.6, Self.body), (5.5, Self.body),
            (9, Self.neck), (13.4, Self.neck), (13.6, Self.neck + 0.5), (Self.mouth, Self.neck + 0.4),
        ]
        let right = side.map { point(along: $0.0, across: $0.1) }
        let left = side.reversed().map { point(along: $0.0, across: -$0.1) }
        return right + left
    }
}

/// The champagne going off (`FigureTimeline.sprayBursts`) and spraying
/// (`FigureJoints.spray`). At each burst a cloud of drops flies out of the
/// mouth at once with a puff of foam (and the cork, the first time); after
/// it a stream keeps leaving along the neck while `spray` dies down, faster
/// and fuller the higher it is. Drops fall as they fly and keep the
/// direction the bottle had when they left.
enum ChampagneSpray {
    /// One drop (or the cork), as drawn.
    struct Drop: Equatable, Sendable {
        var center: CGPoint
        /// A drop's radius; the cork's half length.
        var radius: Double
        var opacity: Double
        /// The cork's direction, radians like the joints' (0 = down); nil
        /// for a round drop.
        var angle: Double? = nil
    }

    /// How long a drop of the stream flies, seconds.
    static let life = 0.62
    /// Drops of the stream in the air at full spray.
    static let count = 44
    /// Speed out of the mouth at full spray, grid units per second.
    static let speed = 50.0
    /// Spread around the neck's direction, degrees each way.
    static let spread = 13.0
    /// A burst: how many drops at once, how long they fly, how far they
    /// spread (degrees each way), their slowest and fastest speed.
    static let burstCount = 34
    static let burstLife = 0.8
    static let burstSpread = 42.0
    static let burstSpeed = 55.0...140.0
    /// How fast a burst's drops slow down (per second): the cloud bursts
    /// out to `burstSpeed / burstDrag` and rains down from there.
    static let burstDrag = 5.5
    /// The foam puffing out of the mouth at a burst: blobs and seconds.
    static let foamCount = 10
    static let foamLife = 0.34
    /// How long the cork is followed, its speed and size (half length).
    static let corkLife = 1.0
    static let corkSpeed = 95.0
    static let corkSize = 2.4
    /// Pull down, grid units per second squared.
    static let gravity = 120.0
    /// How long anything flies after the spray stops.
    static let tail = max(life, burstLife, corkLife)
    /// Where drops fade out: the top's box (`FigureSkeleton.peekBox`), less
    /// `fade` at each side, so they thin out instead of being cut off.
    static let box = FigureSkeleton.peekBox
    static let fade = 9.0

    /// The drops in the air at `time` of a timeline that sprays during
    /// `window` and goes off at `bursts`, given the pose at any earlier time
    /// (`pose`).
    static func drops(
        at time: Double, window: ClosedRange<Double>, bursts: [Double] = [],
        pose: (Double) -> FigureJoints
    ) -> [Drop] {
        guard time >= window.lowerBound, time <= window.upperBound + tail else { return [] }
        var drops: [Drop] = []
        func bottle(at birth: Double) -> (FigureBottle, FigureJoints)? {
            let joints = pose(birth)
            return FigureBottle(joints, skeleton: FigureSkeleton(joints)).map { ($0, joints) }
        }
        func direction(_ bottle: FigureBottle) -> Double { atan2(bottle.axis.dx, bottle.axis.dy) }
        func flown(from tip: CGPoint, angle: Double, velocity: Double, age: Double, drag: Double = 0) -> CGPoint {
            let distance = drag > 0 ? velocity * (1 - exp(-drag * age)) / drag : velocity * age
            return CGPoint(
                x: tip.x + sin(angle) * distance,
                y: tip.y + cos(angle) * distance + gravity * age * age / 2
            )
        }
        func faded(_ center: CGPoint, _ fade: Double) -> Double {
            let edge = min(center.x - box.minX, box.maxX - center.x, center.y - box.minY, box.maxY - center.y)
            return min(max(edge / fade, 0), 1)
        }
        func add(_ center: CGPoint, radius: Double, opacity: Double) {
            let opacity = opacity * faded(center, fade)
            if opacity > 0.02 { drops.append(Drop(center: center, radius: radius, opacity: opacity)) }
        }

        // The stream.
        for index in 0..<count {
            // Drop `index` leaves every `life`, staggered across the drops.
            let offset = Double(index) / Double(count) * life
            let cycle = ((time - offset) / life).rounded(.down)
            let birth = offset + cycle * life
            let age = time - birth
            guard window.contains(birth), age > 0.015, let (bottle, joints) = bottle(at: birth) else { continue }
            let (keep, turn, pace) = jitter(index, Int(cycle))
            guard keep < joints.spray else { continue }
            let angle = direction(bottle) + (turn - 0.5) * 2 * spread * .pi / 180
            let velocity = speed * (0.72 + 0.56 * pace) * (0.55 + 0.45 * joints.spray)
            let progress = age / life
            add(
                flown(from: bottle.tip, angle: angle, velocity: velocity, age: age),
                radius: 2.3 - 0.9 * progress, opacity: 1 - progress * progress
            )
        }

        for (number, burst) in bursts.enumerated() {
            let age = time - burst
            guard age > 0, age < tail, let (bottle, _) = bottle(at: burst) else { continue }
            let axis = direction(bottle)
            // The cloud.
            if age < burstLife {
                let progress = age / burstLife
                for index in 0..<burstCount {
                    let (turn, pace, size) = jitter(index, -1 - number)
                    let angle = axis + (turn - 0.5) * 2 * burstSpread * .pi / 180
                    let velocity = burstSpeed.lowerBound + (burstSpeed.upperBound - burstSpeed.lowerBound) * pace
                    add(
                        flown(from: bottle.tip, angle: angle, velocity: velocity, age: age, drag: burstDrag),
                        radius: (1.5 + 1.5 * size) * (1 - 0.45 * progress), opacity: 1 - progress * progress
                    )
                }
            }
            // The foam puffing out and fading.
            if age < foamLife {
                let progress = age / foamLife
                for index in 0..<foamCount {
                    let (along, across, size) = jitter(index, -100 - number)
                    add(
                        bottle.point(
                            along: FigureBottle.mouth + (2 + 11 * along) * sqrt(progress),
                            across: (across - 0.5) * 10 * sqrt(progress)
                        ),
                        radius: (2 + 2.6 * size) * (0.6 + 0.7 * progress), opacity: 1 - progress
                    )
                }
            }
            // The cork, the first time: shot out a little higher than the
            // neck, tumbling.
            if number == 0, age < corkLife {
                let angle = axis + (.pi - axis) * 0.15
                let center = flown(from: bottle.tip, angle: angle, velocity: corkSpeed, age: age)
                let opacity = faded(center, 4)
                if opacity > 0.02 {
                    drops.append(Drop(center: center, radius: corkSize, opacity: opacity, angle: angle + age * 4 * .pi))
                }
            }
        }
        return drops
    }

    /// Three fixed pseudo-random numbers in 0..<1 for drop `index` of `cycle`.
    static func jitter(_ index: Int, _ cycle: Int) -> (Double, Double, Double) {
        var state = UInt64(truncatingIfNeeded: index &* 7919 &+ cycle &* 104_729) &+ 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }
        return (next(), next(), next())
    }
}

/// A flexed biceps (`FigureJoints.flex`): a bump on the upper arm, on the
/// side the forearm folds to; only on a bent arm (from 15° of bend, full
/// from 50°), so a straight one stays smooth.
enum FigureBiceps {
    /// The bump on `arm` (shoulder, elbow, hand): its centre and radius at
    /// `flex` for a limb `width` wide; nil when not flexed.
    static func bump(_ arm: [CGPoint], flex: Double, width: CGFloat) -> (center: CGPoint, radius: CGFloat)? {
        guard flex > 0.01, arm.count == 3 else { return nil }
        let shoulder = arm[0], elbow = arm[1], hand = arm[2]
        let dx = elbow.x - shoulder.x, dy = elbow.y - shoulder.y
        let length = max(hypot(dx, dy), 1e-6)
        var normal = CGVector(dx: -dy / length, dy: dx / length)
        if normal.dx * (hand.x - elbow.x) + normal.dy * (hand.y - elbow.y) < 0 {
            normal = CGVector(dx: -normal.dx, dy: -normal.dy)
        }
        let fx = hand.x - elbow.x, fy = hand.y - elbow.y
        let cosine = (dx * fx + dy * fy) / (length * max(hypot(fx, fy), 1e-6))
        let bend = acos(min(max(cosine, -1), 1)) * 180 / .pi
        let flexed = CGFloat(flex) * min(max((bend - 15) / 35, 0), 1)
        guard flexed > 0.01 else { return nil }
        let radius = width * 0.42 * flexed
        let lift = width * 0.32 * flexed
        // A little nearer the elbow than the shoulder, like a real one.
        let center = CGPoint(
            x: shoulder.x + dx * 0.56 + normal.dx * lift,
            y: shoulder.y + dy * 0.56 + normal.dy * lift
        )
        return (center, radius)
    }
}
