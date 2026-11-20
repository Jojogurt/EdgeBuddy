import CoreGraphics
@testable import EdgeBuddy
import Testing

/// The champagne going off and the bodybuilder's poses: two more opt-in
/// celebrations on the top.
@Suite("Champagne and flex - celebrations with a prop and poses")
struct ChampagneAndFlexTests {
    private let edge = Double(FigureSkeleton.edgeY)
    private let cap = Double(FigureSkeleton.limbWidth) / 2

    private func feetBottom(_ joints: FigureJoints) -> Double {
        let s = FigureSkeleton(joints)
        return Double(max(s.end(of: .legL).y, s.end(of: .legR).y)) + cap
    }

    private func samples(_ timeline: FigureTimeline) -> [Double] {
        Array(stride(from: 0, through: timeline.duration, by: 1.0 / 120))
    }

    private func drops(_ timeline: FigureTimeline, at time: Double) -> [ChampagneSpray.Drop] {
        timeline.sprayWindow.map { window in
            ChampagneSpray.drops(at: time, window: window, bursts: timeline.sprayBursts) { timeline.joints(at: $0) }
        } ?? []
    }

    private func timeline(_ action: FigureAction, repeats: Int? = nil) -> FigureTimeline {
        FigureTimeline(action: action, entrance: nil, reduceMotion: false, variation: FigureVariation(repeats: repeats))
    }

    @Test("Played on the top only, opt-in, and pinnable there", arguments: [
        (FigureAction.champagne, FigurePose.champagne), (.flex, .flex),
    ])
    func repertoire(action: FigureAction, pose: FigurePose) {
        #expect(FigureRepertoire.top.contains(action))
        #expect(FigureRepertoire.optIn.contains(action))
        #expect(!FigureRepertoire.bottom.contains(action) && !FigureRepertoire.side.contains(action))
        #expect(pose.edges == .top)
        #expect(pose.action(at: .top) == action)
        #expect(pose.action(at: .bottom) == .rest)
        #expect(FigureAction(name: action.name) == action)
    }

    @Test("The feet stay on the edge throughout", arguments: [
        (FigureAction.champagne, 1), (.champagne, 2), (.flex, 1), (.flex, 2),
    ])
    func feetPlanted(action: FigureAction, repeats: Int) {
        let timeline = timeline(action, repeats: repeats)
        for time in samples(timeline) {
            #expect(abs(feetBottom(timeline.joints(at: time)) - edge) < 0.4, "feet off the edge at \(time)")
        }
        #expect(timeline.walkWindow == nil && timeline.walkDistance == nil)
    }

    // MARK: - Champagne

    @Test("The bottle comes and goes: none at the start and the end, held while it sprays")
    func bottle() throws {
        let timeline = timeline(.champagne)
        #expect(timeline.joints(at: 0).bottle == 0)
        #expect(timeline.final.bottle == 0 && timeline.final == .rest)
        let window = try #require(timeline.sprayWindow)
        for time in stride(from: window.lowerBound, through: window.upperBound, by: 0.02) {
            #expect(timeline.joints(at: time).bottle == 1)
        }
        // It never sprays before it is in the hand or after the swig.
        for time in samples(timeline) where !window.contains(time) {
            #expect(timeline.joints(at: time).spray == 0)
        }
        #expect(timeline.sprayBursts.allSatisfy { window.contains($0) })
    }

    @Test("Goes off to the right, then to the left, once each per repeat", arguments: [1, 2])
    func burstsAlternate(repeats: Int) throws {
        let timeline = timeline(.champagne, repeats: repeats)
        #expect(timeline.sprayBursts.count == 2 * repeats)
        #expect(timeline.sprayBursts == timeline.sprayBursts.sorted())
        for (index, burst) in timeline.sprayBursts.enumerated() {
            let pose = timeline.joints(at: burst)
            let skeleton = FigureSkeleton(pose)
            let bottle = try #require(FigureBottle(pose, skeleton: skeleton))
            let right = index.isMultiple(of: 2)
            // Tipped up and out to its side.
            #expect(bottle.axis.dy < 0)
            #expect(right ? bottle.axis.dx > 0 : bottle.axis.dx < 0)
            // A burst: a cloud of drops at once, out on that side.
            let cloud = drops(timeline, at: burst + 0.12)
            #expect(cloud.count > 25)
            let head = Double(skeleton.head.x)
            #expect(cloud.allSatisfy { right ? $0.center.x > head : $0.center.x < head })
        }
    }

    @Test("It is shaken before each burst")
    func shaken() {
        let timeline = timeline(.champagne)
        for burst in timeline.sprayBursts {
            let before = timeline.keyframes.filter { $0.time < burst && $0.time > burst - 1.2 }
            #expect(before.filter { $0.joints == FigureEdgePoses.champagneShakeUp }.count >= 3)
        }
    }

    @Test("The cork flies out at the first burst only")
    func cork() throws {
        let timeline = timeline(.champagne)
        let first = try #require(timeline.sprayBursts.first)
        let second = try #require(timeline.sprayBursts.dropFirst().first)
        let corks = drops(timeline, at: first + 0.05).filter { $0.angle != nil }
        #expect(corks.count == 1)
        let tip = try #require(FigureBottle(timeline.joints(at: first), skeleton: FigureSkeleton(timeline.joints(at: first)))).tip
        // Up and away from the mouth.
        #expect(try #require(corks.first).center.y < tip.y)
        #expect(drops(timeline, at: first - 0.01).allSatisfy { $0.angle == nil })
        #expect(drops(timeline, at: second + 0.05).allSatisfy { $0.angle == nil })
    }

    @Test("Hold frame: going off to the right, the other fist up")
    func holdFrame() throws {
        let timeline = timeline(.champagne)
        let hold = try #require(timeline.holdTime)
        let pose = timeline.joints(at: hold)
        #expect(pose == FigureEdgePoses.champagneRight)
        let skeleton = FigureSkeleton(pose)
        let bottle = try #require(FigureBottle(pose, skeleton: skeleton))
        #expect(bottle.tip.y < skeleton.torsoTop.y && bottle.tip.x > skeleton.head.x)
        #expect(skeleton.end(of: .armL).y < skeleton.head.y)
        let air = drops(timeline, at: hold)
        #expect(air.count > 12)
        #expect(air.allSatisfy { $0.center.x > skeleton.head.x })
    }

    @Test("Drops fade out before the box's edges and stop after the spray", arguments: [1, 2])
    func dropsInBox(repeats: Int) throws {
        let timeline = timeline(.champagne, repeats: repeats)
        let box = FigureSkeleton.peekBox
        for time in samples(timeline) {
            for drop in drops(timeline, at: time) {
                #expect(drop.opacity > 0 && drop.opacity <= 1)
                #expect(box.contains(drop.center), "drop outside at \(time)")
            }
        }
        let window = try #require(timeline.sprayWindow)
        #expect(drops(timeline, at: window.lowerBound - 0.01).isEmpty)
        #expect(drops(timeline, at: window.upperBound + ChampagneSpray.tail + 0.01).isEmpty)
    }

    @Test("Drops are deterministic: the same time draws the same spray")
    func deterministic() throws {
        let timeline = timeline(.champagne)
        let burst = try #require(timeline.sprayBursts.first)
        #expect(drops(timeline, at: burst + 0.1) == drops(timeline, at: burst + 0.1))
    }

    @Test("Other actions and Reduce Motion never spray")
    func noSpray() {
        for action in FigureAction.allCases where action != .champagne {
            let timeline = timeline(action)
            #expect(timeline.sprayWindow == nil && timeline.sprayBursts.isEmpty)
        }
        let reduced = FigureTimeline(action: .champagne, entrance: .spring, reduceMotion: true)
        #expect(reduced.sprayWindow == nil && reduced.sprayBursts.isEmpty)
    }

    // MARK: - Flex

    @Test("Hold frame: a front double biceps, fists up by the head")
    func flexHold() throws {
        let timeline = timeline(.flex)
        let hold = try #require(timeline.holdTime)
        let pose = timeline.joints(at: hold)
        #expect(pose == FigureEdgePoses.flexDoubleBiceps)
        let s = FigureSkeleton(pose)
        for arm in [s.armL, s.armR] {
            #expect(arm[2].y < s.torsoTop.y)
            let bump = try #require(FigureBiceps.bump(arm, flex: pose.flex, width: FigureSkeleton.limbWidth))
            // The bump bulges up, on the forearm's side of the upper arm.
            #expect(bump.center.y < (arm[0].y + arm[1].y) / 2)
        }
        #expect(FigureBiceps.bump(s.armR, flex: 0, width: FigureSkeleton.limbWidth) == nil)
        #expect(timeline.final.flex == 0 && timeline.final == .rest)
    }

    @Test("Goes through the poses in order, each squeezed; the side chest turns right, then left", arguments: [1, 2])
    func routine(repeats: Int) {
        let timeline = timeline(.flex, repeats: repeats)
        let poses = FigureEdgePoses.self
        var expected = [poses.flexDoubleBiceps]
        for round in 0..<repeats {
            expected += [
                poses.flexMostMuscular, poses.flexSideChest(facing: round.isMultiple(of: 2) ? 1 : -1),
                poses.flexOneArm, poses.flexAbs,
            ]
        }
        expected.append(poses.flexDoubleBiceps)
        let hit = timeline.keyframes.map(\.joints).filter { expected.contains($0) }
        #expect(hit == expected)
        for pose in expected {
            #expect(timeline.keyframes.contains { $0.joints == poses.squeezed(pose) })
            #expect(poses.squeezed(pose).flex > pose.flex)
        }
    }

    @Test("Distinct poses: hunched fists low, hands at the head, one biceps up")
    func poseShapes() {
        let poses = FigureEdgePoses.self
        let crab = FigureSkeleton(poses.flexMostMuscular)
        #expect(abs(crab.end(of: .armL).x - crab.end(of: .armR).x) < 8)
        #expect(crab.end(of: .armR).y > crab.torsoTop.y)
        let abs = FigureSkeleton(poses.flexAbs)
        for hand in [abs.end(of: .armL), abs.end(of: .armR)] {
            #expect(Swift.abs(hand.y - abs.head.y) < 3)
        }
        // One biceps: the left fist up by the head, flexed; the right arm
        // hanging straight, smooth.
        let one = FigureSkeleton(poses.flexOneArm)
        #expect(one.end(of: .armL).y < one.torsoTop.y && one.end(of: .armL).x < one.hip.x)
        #expect(one.end(of: .armR).y > one.hip.y - 12)
        #expect(FigureBiceps.bump(one.armL, flex: poses.flexOneArm.flex, width: FigureSkeleton.limbWidth) != nil)
        #expect(FigureBiceps.bump(one.armR, flex: poses.flexOneArm.flex, width: FigureSkeleton.limbWidth) == nil)
        let side = FigureSkeleton(poses.flexSideChest(facing: 1))
        // The far hand holds the near wrist, in front of the chest.
        #expect(hypot(side.end(of: .armL).x - side.end(of: .armR).x, side.end(of: .armL).y - side.end(of: .armR).y) < 6)
        #expect(side.end(of: .armR).x > side.hip.x + 10)
    }

    @Test("Never squashed flat, and no arm ever sticks straight out sideways", arguments: [1, 2])
    func cleanTransitions(repeats: Int) {
        let timeline = timeline(.flex, repeats: repeats)
        for time in samples(timeline) {
            let pose = timeline.joints(at: time)
            #expect(abs(pose.facing) == 1, "squashed at \(time)")
            for (arm, elbow) in [(pose.armL, pose.elbowL), (pose.armR, pose.elbowR)] where pose.profile < 0.5 {
                let upper = abs(arm - pose.lean)
                #expect(!(upper > 65 && upper < 115 && abs(elbow) < 20), "arm straight out at \(time)")
            }
        }
    }
}
