import CoreGraphics
@testable import EdgeBuddy
import Testing

/// The nap (asleep on the edge, Z glyphs rising) and the slip (off the edge,
/// caught by the hands, back up): two top actions in the random repertoire.
@Suite("Nap and slip - top actions from the random repertoire")
struct NapAndSlipTests {
    private let edge = Double(FigureSkeleton.edgeY)
    private let poses = FigureEdgePoses.self

    private func samples(_ timeline: FigureTimeline) -> [Double] {
        Array(stride(from: 0, through: timeline.duration, by: 1.0 / 120))
    }

    private func timeline(_ action: FigureAction, repeats: Int? = nil) -> FigureTimeline {
        FigureTimeline(action: action, entrance: nil, reduceMotion: false, variation: FigureVariation(repeats: repeats))
    }

    private func zs(_ timeline: FigureTimeline, at time: Double) -> [SnoozeZs.Glyph] {
        timeline.snoozeWindow.map { SnoozeZs.glyphs(at: time, window: $0, pose: timeline.joints(at: time)) } ?? []
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    @Test("Played at random on the top only (not opt-in), and pinnable there", arguments: [
        (FigureAction.nap, FigurePose.nap), (.slip, .slip),
    ])
    func repertoire(action: FigureAction, pose: FigurePose) {
        #expect(FigureRepertoire.top.contains(action))
        #expect(!FigureRepertoire.optIn.contains(action))
        #expect(!FigureRepertoire.bottom.contains(action) && !FigureRepertoire.side.contains(action))
        #expect(HumanRig.standard.actions(at: .top, room: 0, atScreenEdge: false).contains(action.name))
        #expect(pose.edges == .top)
        #expect(pose.action(at: .top) == action)
        #expect(pose.action(at: .bottom) == .rest)
        #expect(FigureAction(name: action.name) == action)
        #expect(FigureActionName.nap == "nap" && FigureActionName.slip == "slip")
    }

    @Test("Timings follow the sketch: nap 11.42 s with three breaths, slip 4.83 s")
    func timings() {
        #expect(abs(timeline(.nap).duration - 11.42) < 1e-9)
        #expect(abs(timeline(.slip).duration - 4.83) < 1e-9)
        // A breath is 2.4 s, a look around 0.45 s.
        #expect(abs(timeline(.nap, repeats: 3).duration - timeline(.nap, repeats: 2).duration - 2.4) < 1e-9)
        #expect(abs(timeline(.slip, repeats: 2).duration - timeline(.slip, repeats: 1).duration - 0.45) < 1e-9)
        #expect(FigureVariation.repeatRange(.nap).contains(FigureTimeline.canvasRepeats(.nap)))
        #expect(FigureVariation.repeatRange(.slip).contains(FigureTimeline.canvasRepeats(.slip)))
    }

    // MARK: - Nap

    @Test("Nap: yawn, kneel, lie on its side along the edge, breathe, startle, kneel, stand")
    func napSequence() throws {
        let timeline = timeline(.nap)
        let order = [
            poses.napYawn, poses.wormKneel, poses.napAsleep, poses.napInhale, poses.napExhale,
            poses.napStartle, poses.wormKneel, FigureJoints.rest,
        ]
        var keys = timeline.keyframes.map(\.joints)[...]
        for pose in order {
            let index = try #require(keys.firstIndex(of: pose), "missing \(pose)")
            keys = keys[(index + 1)...]
        }
        let asleep = FigureSkeleton(poses.napAsleep)
        #expect(poses.napAsleep.profile == 1 && poses.napAsleep.lean == 90)
        // Lying flat: the torso level, the head at the far end, both hands on their spots.
        #expect(abs(asleep.hip.y - asleep.torsoTop.y) < 0.5)
        #expect(asleep.head.x > asleep.torsoTop.x)
        #expect(distance(asleep.end(of: .armR), poses.napPillow) < 1e-6)
        #expect(distance(asleep.end(of: .armL), poses.napHand) < 1e-6)
        // The startle jerks the head up off the hand.
        #expect(FigureSkeleton(poses.napStartle).head.y < asleep.head.y - 3)
    }

    @Test("Nap: the hands stay on their spots while it sleeps", arguments: [2, 3])
    func napHandsHold(repeats: Int) throws {
        let timeline = timeline(.nap, repeats: repeats)
        let window = try #require(timeline.snoozeWindow)
        for time in stride(from: window.lowerBound, through: window.upperBound + 0.49, by: 1.0 / 60) {
            let s = FigureSkeleton(timeline.joints(at: time))
            #expect(distance(s.end(of: .armR), poses.napPillow) < 0.6, "pillow hand at \(time)")
            #expect(distance(s.end(of: .armL), poses.napHand) < 0.6, "far hand at \(time)")
        }
    }

    @Test("Nap: lies within the figure's own box, above the edge but for the far elbow and brushing feet", arguments: [2, 3])
    func napInBox(repeats: Int) {
        let timeline = timeline(.nap, repeats: repeats)
        let cap = Double(FigureSkeleton.limbWidth) / 2, r = Double(FigureSkeleton.headRadius)
        for time in samples(timeline) {
            let pose = timeline.joints(at: time)
            // The stage mirrors a figure heading left around the box's middle.
            for joints in [pose, pose.with { $0.facing = 1 - 2 * $0.profile; $0.x *= $0.facing }] {
                let s = FigureSkeleton(joints)
                let points = s.armL + s.armR + s.legL + s.legR + [s.hip, s.torsoTop]
                #expect(points.allSatisfy { Double($0.x) - cap >= -0.3 && Double($0.x) + cap <= 100.3 }, "x at \(time)")
                #expect(Double(s.head.x) - r >= -0.3 && Double(s.head.x) + r <= 100.3)
                // Head, torso and the near arm never go behind the card.
                #expect(Double(s.head.y) + r <= edge + 0.3)
                #expect((s.armR + [s.hip, s.torsoTop]).allSatisfy { Double($0.y) + cap <= edge + 2 }, "near side at \(time)")
                // The far elbow folds behind the edge (as in the sketch); feet and
                // knees only brush it while the legs swing out to lie down.
                #expect((s.legL + s.legR).allSatisfy { Double($0.y) + cap <= edge + 3.2 }, "legs at \(time)")
            }
        }
    }

    @Test("Nap: lies within the figure's own box, so any top it fits on has room for it")
    func napNeedsNoTravel() {
        #expect(FigureTimeline.minimumTravel(.nap) == nil)
        #expect(FigureRepertoire.actions(for: .top, room: 0).contains(.nap))
        #expect(FigureRepertoire.actions(for: .top, room: 0).contains(.slip))
    }

    @Test("Z glyphs: none awake, one every 0.9 s asleep, rising and growing, gone 0.2 s after waking")
    func zGlyphs() throws {
        let timeline = timeline(.nap)
        let window = try #require(timeline.snoozeWindow)
        #expect(abs(window.upperBound - window.lowerBound - 3 * 2.4) < 1e-9)
        #expect(zs(timeline, at: window.lowerBound - 0.01).isEmpty)
        #expect(zs(timeline, at: window.upperBound + SnoozeZs.fadeOut + 0.001).isEmpty)
        // Fading on waking.
        let before = zs(timeline, at: window.upperBound - 0.001).map(\.opacity).reduce(0, +)
        let fading = zs(timeline, at: window.upperBound + 0.1).map(\.opacity).reduce(0, +)
        #expect(before > 0 && fading < before * 0.6)
        // One glyph followed through its life: born beside the head, up and away from the face.
        let birth = window.lowerBound + SnoozeZs.interval
        let early = try #require(zs(timeline, at: birth + 0.3).max { $0.center.y < $1.center.y })
        let late = try #require(zs(timeline, at: birth + 1.8).min { $0.center.y < $1.center.y })
        #expect(late.center.y < early.center.y && late.center.x > early.center.x && late.size > early.size)
        let head = FigureSkeleton(timeline.joints(at: birth + 0.3)).head
        #expect(early.center.x > head.x && early.center.y < head.y)
        // At most three in the air, all in the box, the same at the same time.
        for time in samples(timeline) {
            let glyphs = zs(timeline, at: time)
            #expect(glyphs.count <= 3)
            for glyph in glyphs {
                #expect(glyph.opacity > 0 && glyph.opacity <= 1)
                for point in glyph.points {
                    #expect(FigureSkeleton.peekBox.insetBy(dx: -1, dy: 0).contains(point), "Z outside at \(time)")
                }
            }
        }
        #expect(zs(timeline, at: birth + 1) == zs(timeline, at: birth + 1))
    }

    @Test("Z glyphs drift to the side the figure faces; the letter always reads as a Z")
    func zMirrored() throws {
        let timeline = timeline(.nap)
        let window = try #require(timeline.snoozeWindow)
        let time = window.lowerBound + 1.5
        let pose = timeline.joints(at: time)
        let left = pose.with { $0.facing = -1 }
        let right = try #require(SnoozeZs.glyphs(at: time, window: window, pose: pose).first)
        let mirrored = try #require(SnoozeZs.glyphs(at: time, window: window, pose: left).first)
        #expect(right.center.x > FigureSkeleton(pose).head.x)
        #expect(mirrored.center.x < FigureSkeleton(left).head.x)
        // The top bar runs left to right, the diagonal back down to the left.
        let points = mirrored.points
        #expect(points[1].x > points[0].x && points[2].x < points[1].x && points[3].x > points[2].x)
    }

    @Test("Other actions and Reduce Motion never show Z glyphs")
    func noZs() {
        for action in FigureAction.allCases where action != .nap {
            #expect(timeline(action).snoozeWindow == nil)
        }
        #expect(FigureTimeline(action: .nap, entrance: .spring, reduceMotion: true).snoozeWindow == nil)
    }

    // MARK: - Slip

    @Test("Slip: falls behind the card; only the hands show while it hangs, the head comes up over the edge")
    func slipFall() throws {
        let timeline = timeline(.slip)
        let caught = FigureSkeleton(poses.slipCaught)
        let hang = FigureSkeleton(FigureTimeline.climbHang)
        for s in [caught, hang] {
            // Hands on the edge, everything else below it.
            #expect(s.end(of: .armL).y < edge && s.end(of: .armL).y > edge - 6)
            #expect(Double(s.head.y - FigureSkeleton.headRadius) > edge)
        }
        let pulled = FigureSkeleton(poses.slipLookLeft)
        #expect(pulled.head.y < edge - FigureSkeleton.headRadius && pulled.hip.y > edge)
        // The turn back to the front happens while the head is hidden.
        let catchTime = try #require(timeline.keyframes.first { $0.joints == poses.slipCaught }).time
        for time in samples(timeline) where time > catchTime {
            let pose = timeline.joints(at: time)
            let s = FigureSkeleton(pose)
            if pose.profile > 0.01, pose.profile < 0.99 {
                #expect(Double(s.head.y - FigureSkeleton.headRadius) > edge, "turning in sight at \(time)")
            }
        }
        // It hangs at some point with nothing but the hands above the edge.
        #expect(samples(timeline).contains { time in
            let s = FigureSkeleton(timeline.joints(at: time))
            return Double(s.head.y - FigureSkeleton.headRadius) > edge && s.end(of: .armR).y < edge
        })
    }

    @Test("Slip: hangs, pulls up and climbs back with the climb entrance's own poses")
    func slipReusesClimb() throws {
        let keys = timeline(.slip).keyframes.map(\.joints)
        for pose in [FigureTimeline.climbHang, FigureTimeline.climbPulled, FigureTimeline.climbKnee] {
            #expect(keys.contains(pose))
        }
        let pull = try #require(keys.firstIndex(of: FigureTimeline.climbPulled))
        let knee = try #require(keys.firstIndex(of: FigureTimeline.climbKnee))
        #expect(pull < knee)
        // The wipe: the near hand across the forehead, from its side to the other.
        let wipeIn = FigureSkeleton(poses.slipWipeIn), wipeOut = FigureSkeleton(poses.slipWipeOut)
        #expect(abs(wipeIn.end(of: .armR).y - wipeIn.head.y) < 4 && abs(wipeOut.end(of: .armR).y - wipeOut.head.y) < 4)
        #expect(wipeIn.end(of: .armR).x > wipeIn.head.x && wipeOut.end(of: .armR).x < wipeOut.head.x)
        // The elbow stays out to the side while the hand is up.
        #expect(wipeIn.armR[1].x > wipeIn.armR[0].x && wipeOut.armR[1].x > wipeOut.armR[0].x)
    }

    // MARK: - Pins, still windows, endings

    @Test("Hold frames: asleep with a Z beside the head; pulled up, looking over the edge")
    func holdFrames() throws {
        let nap = timeline(.nap)
        let napHold = try #require(nap.holdTime)
        #expect(nap.joints(at: napHold) == poses.napExhale)
        #expect(!zs(nap, at: napHold).isEmpty)
        let slip = timeline(.slip)
        #expect(slip.joints(at: try #require(slip.holdTime)) == poses.slipLookLeft)
    }

    @Test("Still windows: never while the Z glyphs move, and the clock stops in the holds", arguments: [
        FigureAction.nap, .slip, .champagne,
    ])
    func stillWindows(action: FigureAction) {
        let looped = FigureTimeline(
            action: action, entrance: .spring, reduceMotion: false,
            variation: FigureVariation(holdBefore: 0.6, repeats: 1, holdAfter: 0.8, exit: .spring, hiddenPause: 1)
        )
        let windows = looped.stillWindows
        #expect(windows.count >= 2)
        for window in windows {
            #expect(window.upperBound - window.lowerBound >= FigureTimeline.minimumStill)
            #expect(looped.joints(at: window.lowerBound) == looped.joints(at: window.upperBound))
            for effect in looped.effectWindows {
                #expect(!(window.lowerBound < effect.upperBound - 1e-9 && window.upperBound > effect.lowerBound + 1e-9))
            }
        }
        // A one-off play (no loop) ends standing at rest: the stage stops the clock there.
        #expect(timeline(action).final == .rest)
    }

    @Test("A scroll or the end of a run takes it back cleanly: rest, then the exit", arguments: [
        FigureAction.nap, .slip,
    ])
    func endings(action: FigureAction) throws {
        var generator = SystemRandomNumberGenerator()
        for entrance in [FigureEntrance.spring, .climb] {
            let looped = FigureTimeline(
                action: action, entrance: entrance, reduceMotion: false,
                variation: FigureVariation.random(for: action, exit: entrance, using: &generator)
            )
            #expect(looped.final == FigureTimeline.hiddenPose(entrance))
            #expect(looped.hiddenPause != nil)
            let chained = FigureTimeline(
                action: action, entrance: nil, reduceMotion: false,
                variation: FigureVariation.random(for: action, exit: entrance, using: &generator).chained(continues: true)
            )
            #expect(chained.final == .rest && chained.hiddenPause == nil)
        }
        let leaving = FigureTimeline(
            action: .rest, entrance: nil, reduceMotion: false,
            variation: FigureVariation.leaving(exit: .spring, using: &generator)
        )
        #expect(leaving.final == FigureTimeline.hiddenPose(.spring))
        let reduced = FigureTimeline(action: action, entrance: .spring, reduceMotion: true)
        #expect(reduced.keyframes.allSatisfy { $0.joints == .rest } && reduced.holdTime == nil)
    }

    // MARK: - Weights

    @Test("The nap comes up about a third as often as the others")
    func napWeight() {
        #expect(FigureRepertoire.weight(.nap) < 0.5)
        #expect(FigureRepertoire.weight(.slip) == 1 && FigureRepertoire.weight(.wave) == 1)
        #expect(HumanRig.standard.info("nap", at: .top).weight == FigureRepertoire.weight(.nap))
        var generator = SplitMix(state: 5)
        let pool: [FigureAction] = FigureRepertoire.top.filter { !FigureRepertoire.optIn.contains($0) }
        var counts: [FigureAction: Int] = [:]
        for _ in 0..<9000 {
            counts[FigureRepertoire.next(after: nil, from: pool, using: &generator), default: 0] += 1
        }
        let ratio = Double(counts[.nap] ?? 0) / Double(counts[.wave] ?? 1)
        #expect(ratio > 0.25 && ratio < 0.42, "nap/wave \(ratio)")
    }

    @Test("Even weights draw exactly as without them (seeded picks unchanged)")
    func evenWeights() {
        let names = ["a", "b", "c", "d"]
        var plain = SplitMix(state: 9), weighted = SplitMix(state: 9)
        for _ in 0..<200 {
            let a = FigureRepertoire.next(after: "a", from: names, fallback: "rest", using: &plain)
            let b = FigureRepertoire.next(after: "a", from: names, fallback: "rest", weight: { _ in 1 }, using: &weighted)
            #expect(a == b)
        }
    }
}

/// A deterministic generator (SplitMix64).
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
