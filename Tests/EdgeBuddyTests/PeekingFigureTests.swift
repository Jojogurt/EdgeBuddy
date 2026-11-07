import Foundation
import Testing
@testable import EdgeBuddy

@Suite("Peeking figure — rig timelines, random actions, anchors")
struct PeekingFigureTests {
    private let entrance = 0.66
    private let edge = Double(FigureSkeleton.edgeY)

    @Test("Action lengths match the canvas", arguments: [
        (FigureAction.rest, 0.48),
        (.wave, 2.1),
        (.jumpingJacks, 2.36),
        (.sideStretch, 3.62),
        (.march, 2.95),
        (.wormWalk, 4.48),
        (.handstand, 4.16),
        (.run, 3.16),
    ])
    func actionDurations(action: FigureAction, expected: Double) {
        let played = FigureTimeline(action: action, entrance: nil, reduceMotion: false)
        #expect(abs(played.duration - expected) < 1e-9)
        let entered = FigureTimeline(action: action, entrance: .spring, reduceMotion: false)
        #expect(abs(entered.duration - (expected + entrance)) < 1e-9)
    }

    @Test("Every action starts and ends at rest", arguments: [
        FigureAction.rest, .wave, .jumpingJacks, .sideStretch, .march, .wormWalk, .handstand, .run,
    ])
    func endsAtRest(action: FigureAction) {
        let timeline = FigureTimeline(action: action, entrance: nil, reduceMotion: false)
        #expect(timeline.joints(at: 0) == .rest)
        #expect(timeline.final == .rest)
        #expect(timeline.joints(at: timeline.duration + 1) == .rest)
    }

    @Test("Entrance rises from behind the card, overshoots, settles")
    func entranceSpring() {
        let timeline = FigureTimeline(action: .wave, entrance: .spring, reduceMotion: false)
        #expect(timeline.joints(at: 0).y == 64 + FigureTimeline.behind)
        #expect(abs(timeline.joints(at: 0.36).y - -3) < 1e-9)
        #expect(abs(timeline.joints(at: 0.52).y) < 1e-6)
        #expect(timeline.joints(at: entrance) == .rest)
        #expect(timeline.opacity(at: 0) == 1)
    }

    @Test("Reduce Motion: rest only, a 0.2 s crossfade in")
    func reduceMotion() {
        let timeline = FigureTimeline(action: .jumpingJacks, entrance: .spring, reduceMotion: true)
        #expect(timeline.duration == 0.2)
        #expect(timeline.keyframes.allSatisfy { $0.joints == .rest })
        #expect(timeline.opacity(at: 0) == 0)
        #expect(timeline.opacity(at: 0.1) == 0.5)
        #expect(timeline.opacity(at: 0.2) == 1)
        let tapped = FigureTimeline(action: .wave, entrance: nil, reduceMotion: true)
        #expect(tapped.opacity(at: 0) == 1)
    }

    @Test("Rest skeleton stands on the card edge, head on the axis")
    func restSkeleton() {
        let skeleton = FigureSkeleton(.rest)
        #expect(skeleton.hip == CGPoint(x: 50, y: 70))
        #expect(abs(skeleton.head.x - 50) < 1e-9)
        #expect(abs(skeleton.head.y - 30) < 1e-9)
        // The feet (round caps included) end right on the card's edge.
        for leg in [skeleton.legL, skeleton.legR] {
            #expect(abs(leg[2].y + FigureSkeleton.limbWidth / 2 - FigureSkeleton.edgeY) < 0.5)
        }
        // The head clears the top of the box.
        #expect(skeleton.head.y - FigureSkeleton.headRadius > FigureSkeleton.peekBox.minY)
        // The whole figure above the edge fits the 100-wide grid.
        let xs = (skeleton.armL + skeleton.armR + skeleton.legL + skeleton.legR).map(\.x)
        #expect(xs.allSatisfy { $0 > 0 && $0 < 100 })
        // Hands on hips: hands at the waist, elbows out past the shoulders.
        for arm in [skeleton.armL, skeleton.armR] {
            #expect(abs(arm[2].x - 50) <= 7)
            #expect(arm[2].y >= 60 && arm[2].y <= 70)
            #expect(abs(arm[1].x - 50) > abs(arm[0].x - 50))
        }
    }

    @Test("Run: profile pose 1:1 with the loader canvas, one cycle = 0.66 s")
    func runPose() {
        let start = FigureJoints.run(phase: 0)
        #expect(start.profile == 1 && start.lean == 9)
        #expect(abs(start.y - -2.5) < 1e-9)
        #expect(abs(start.kneeR - -41) < 1e-9 && abs(start.kneeL - -41) < 1e-9)
        let quarter = FigureJoints.run(phase: 0.25)
        #expect(abs(quarter.legR - 38) < 1e-9 && abs(quarter.legL - -38) < 1e-9)
        #expect(abs(quarter.armR - -42) < 1e-9)
        #expect(abs(quarter.kneeR - -12) < 1e-9 && abs(quarter.kneeL - -70) < 1e-9)
        let cycle = FigureJoints.run(phase: 1)
        #expect(abs(cycle.legR - start.legR) < 1e-9 && abs(cycle.kneeL - start.kneeL) < 1e-9)
        #expect(abs(cycle.y - start.y) < 1e-9)
    }

    @Test("Run: turns into profile, travels during the strides, turns back")
    func runTimeline() throws {
        let run = FigureTimeline(action: .run, entrance: nil, reduceMotion: false)
        let window = try #require(run.walkWindow)
        #expect(abs(window.lowerBound - 0.22) < 1e-9)
        #expect(abs(window.upperBound - (0.22 + 4 * 0.66)) < 1e-9)
        #expect(run.joints(at: 0.11).profile > 0 && run.joints(at: 0.11).profile < 1)
        #expect(run.joints(at: 1).profile == 1)
        #expect(run.joints(at: run.duration).profile == 0)
        #expect(FigureTimeline(action: .run, entrance: nil, reduceMotion: true).walkWindow == nil)
        // The lowest stride touches the edge like the standing feet — never sinks.
        let lowest = stride(from: window.lowerBound, through: window.upperBound, by: 0.01).map { time in
            let skeleton = FigureSkeleton(run.joints(at: time))
            return max(skeleton.legL[2].y, skeleton.legR[2].y) + FigureSkeleton.limbWidth / 2
        }.max() ?? 0
        #expect(abs(lowest - edge) < 0.5)
    }

    @Test("Profile skeleton: shoulders and hips on one point, far limbs faded, mirror")
    func profileSkeleton() {
        let side = FigureSkeleton(.run(phase: 0.25))
        #expect(side.legL[0] == side.legR[0])
        #expect(abs(side.armL[0].x - side.armR[0].x) < 1e-9)
        #expect(abs(side.farLimbOpacity - 0.45) < 1e-9)
        #expect(side.legR[1].x > 50)
        let left = FigureSkeleton(.run(phase: 0.25).with { $0.facing = -1 })
        #expect(abs(left.legR[1].x - (100 - side.legR[1].x)) < 1e-9)
        #expect(FigureSkeleton(.rest).farLimbOpacity == 1)
    }

    @Test("Hidden at accessibility text sizes")
    func visibility() {
        #expect(PeekingFigureMetrics.isShown(dynamicTypeSize: .large))
        #expect(!PeekingFigureMetrics.isShown(dynamicTypeSize: .accessibility1))
        #expect(PeekingFigureMetrics.standard.width == 52)
        #expect(PeekingFigureMetrics.standard.minimumAnchorWidth == 108)
    }

    @Test("Metrics: the default footprint, everything scales with the height")
    func metricsScale() {
        #expect(PeekingFigureMetrics.standard.height == 56)
        #expect(PeekingFigureMetrics.standard.sizes == sizes)
        let double = PeekingFigureMetrics(height: 112)
        #expect(double.width == 104)
        #expect(double.edgeMargin == 56)
        #expect(double.sideMargin == 24)
        #expect(double.minimumAnchorWidth == 216)
        #expect(PeekingFigureMetrics(height: 4).height == PeekingFigureMetrics.minimumHeight)
    }

    @Test("Built-in motion policy: active scene, Reduce Motion and Low Power off")
    func motionPolicy() {
        #expect(FigureMotionPolicy.idleEnabled(reduceMotion: false, lowPowerMode: false, scenePhase: .active))
        #expect(!FigureMotionPolicy.idleEnabled(reduceMotion: true, lowPowerMode: false, scenePhase: .active))
        #expect(!FigureMotionPolicy.idleEnabled(reduceMotion: false, lowPowerMode: true, scenePhase: .active))
        #expect(!FigureMotionPolicy.idleEnabled(reduceMotion: false, lowPowerMode: false, scenePhase: .background))
        #expect(!FigureMotionPolicy.idleEnabled(reduceMotion: false, lowPowerMode: false, scenePhase: .inactive))
    }

    @Test("Running figure: one cycle is the run cycle")
    func runningFigureCycle() {
        #expect(RunningFigure.cycleDuration == FigureJoints.runCycle)
        #expect(RunningFigure.bodyBox == CGRect(x: 0, y: 12, width: 100, height: 104))
    }

    @Test("Climb: hidden at first, hands over the edge, then up to rest in 1.4 s")
    func climb() {
        let timeline = FigureTimeline(action: .wave, entrance: .climb, reduceMotion: false)
        #expect(abs(timeline.duration - (1.4 + 2.1)) < 1e-9)
        // Never appears instantly: nothing above the edge (`FigureSkeleton.edgeY`) at the start.
        let start = FigureSkeleton(timeline.joints(at: 0))
        let startPoints = start.armL + start.armR + start.legL + start.legR + [start.torsoTop]
        #expect(startPoints.allSatisfy { $0.y > edge + FigureSkeleton.limbWidth / 2 })
        #expect(start.head.y - FigureSkeleton.headRadius > edge)
        // Hanging: only the hands show, just over the edge; the head is hidden.
        let hang = FigureSkeleton(timeline.joints(at: 0.22))
        #expect(hang.armL[2].y < edge && hang.armL[2].y > edge - 8)
        #expect(hang.armR[2].y < edge && hang.armR[2].y > edge - 8)
        #expect(hang.head.y - FigureSkeleton.headRadius > edge)
        // Pulled up: the head clears the edge.
        #expect(FigureSkeleton(timeline.joints(at: 0.72)).head.y + FigureSkeleton.headRadius < edge)
        #expect(timeline.joints(at: 1.4) == .rest)
        #expect(timeline.final == .rest)
    }

    @Test("Tempo scales every time, including the relocation jump")
    func tempo() throws {
        let normal = FigureTimeline(action: .wormWalk, entrance: .climb, reduceMotion: false, relocating: true)
        let fast = FigureTimeline(action: .wormWalk, entrance: .climb, reduceMotion: false, relocating: true, tempo: 2)
        #expect(abs(fast.duration - normal.duration / 2) < 1e-9)
        #expect(abs(try #require(fast.relocatesAt) - FigureTimeline.duckDuration / 2) < 1e-9)
        let window = try #require(fast.walkWindow), normalWindow = try #require(normal.walkWindow)
        #expect(abs(window.lowerBound - normalWindow.lowerBound / 2) < 1e-9)
        // Reduce Motion's crossfade keeps its length.
        #expect(FigureTimeline(action: .wave, entrance: .climb, reduceMotion: true, tempo: 3).duration == 0.2)
    }

    @Test("Relocation re-enters with the chosen entrance, hidden at the jump")
    func relocationClimb() throws {
        let timeline = FigureTimeline(action: .rest, entrance: .climb, reduceMotion: false, relocating: true)
        let jump = try #require(timeline.relocatesAt)
        #expect(FigureSkeleton(timeline.joints(at: jump)).head.y - FigureSkeleton.headRadius > edge)
        #expect(abs(timeline.duration - (0.24 + 0.12 + 1.4 + 0.48)) < 1e-9)
    }

    @Test("Relocation: duck out of sight, jump while hidden, spring up, play")
    func relocation() throws {
        let timeline = FigureTimeline(action: .wave, entrance: nil, reduceMotion: false, relocating: true)
        let jump = try #require(timeline.relocatesAt)
        #expect(timeline.joints(at: 0) == .rest)
        #expect(timeline.joints(at: jump).y == 64 + FigureTimeline.behind)
        // Hidden behind the card at the jump: the head's top is below the edge.
        #expect(FigureSkeleton(timeline.joints(at: jump)).head.y - FigureSkeleton.headRadius > edge)
        #expect(timeline.final == .rest)
        #expect(abs(timeline.duration - (0.24 + 0.12 + 0.66 + 2.1)) < 1e-9)
        #expect(FigureTimeline(action: .wave, entrance: .spring, reduceMotion: false).relocatesAt == nil)
        #expect(FigureTimeline(action: .wave, entrance: nil, reduceMotion: true, relocating: true).relocatesAt == nil)
    }

    @Test("Placement: a new spot is always a real jump, inside the edge")
    func placement() {
        var generator = SystemRandomNumberGenerator()
        for current in stride(from: 0.0, through: 1.0, by: 0.05) {
            for _ in 0..<20 {
                let next = FigurePlacement.next(from: current, using: &generator)
                #expect((0...1).contains(next))
                #expect(abs(next - current) >= FigurePlacement.minimumJump - 1e-9)
            }
        }
    }

    @Test("Placement: fraction maps between the two margins")
    func trailingInset() {
        let right = FigurePlacement.trailingInset(fraction: 1, cardWidth: 360, figureWidth: 52, margin: 28)
        let left = FigurePlacement.trailingInset(fraction: 0, cardWidth: 360, figureWidth: 52, margin: 28)
        #expect(right == 28)
        #expect(left == CGFloat(280))
        // A card narrower than the figure keeps it at the margin.
        #expect(FigurePlacement.trailingInset(fraction: 0, cardWidth: 60, figureWidth: 52, margin: 28) == 28)
    }

    @Test("Worm walk travels a stride per cycle, only while the hands reach; march stays in place")
    func walkWindow() throws {
        let worm = FigureTimeline(action: .wormWalk, entrance: .spring, reduceMotion: false)
        let window = try #require(worm.walkWindow)
        // Get down (1.1 s), the first arch (0.38 s); get up (1.1 s).
        #expect(abs(window.lowerBound - (0.66 + 1.1 + 0.38)) < 1e-9)
        #expect(abs(window.upperBound - (worm.duration - 1.1)) < 1e-9)
        #expect(abs(try #require(worm.walkDistance) - 3 * FigureEdgePoses.wormStride) < 1e-9)
        #expect(FigureTimeline.travel(.wormWalk, repeats: 3) == worm.walkDistance)
        #expect(worm.walkProgress(at: 0) == 0)
        #expect(worm.walkProgress(at: worm.duration) == 1)
        // Still while the feet hop up to the hands (the second arch).
        let arch = window.lowerBound + 0.76
        #expect(abs(try #require(worm.walkProgress(at: arch - 0.37)) - 1.0 / 3) < 1e-9)
        #expect(abs(try #require(worm.walkProgress(at: arch)) - 1.0 / 3) < 1e-9)
        #expect(FigureTimeline(action: .march, entrance: .spring, reduceMotion: false).walkWindow == nil)
        let reduced = FigureTimeline(action: .wormWalk, entrance: .spring, reduceMotion: true)
        #expect(reduced.walkWindow == nil && reduced.walkDistance == nil)
        // The run glides to a target the stage picks.
        #expect(FigureTimeline(action: .run, entrance: nil, reduceMotion: false).walkDistance == nil)
    }

    // MARK: - Looping

    private func loopVariation(
        repeats: Int, exit: FigureEntrance = .climb
    ) -> FigureVariation {
        FigureVariation(holdBefore: 0.7, repeats: repeats, holdAfter: 1.1, exit: exit, hiddenPause: 2)
    }

    @Test("Exit is the entrance in reverse: same length, from rest down to hidden", arguments: [
        FigureEntrance.climb, .spring,
    ])
    func exitMirrorsEntrance(entrance: FigureEntrance) {
        let enter = FigureTimeline.entranceSteps(entrance)
        let exit = FigureTimeline.exitSteps(entrance)
        let enterDuration: Double = enter.map(\.duration).reduce(0, +)
        let exitDuration: Double = exit.map(\.duration).reduce(0, +)
        #expect(abs(enterDuration - exitDuration) < 1e-9)
        #expect(exit.last?.joints == FigureTimeline.hiddenPose(entrance))
        #expect(Array(exit.dropLast().map(\.joints)) == Array(enter.dropLast().map(\.joints).reversed()))
    }

    @Test("Reversed easings mirror their forward curve")
    func reversedEasing() {
        for easing in [FigureTimeline.Easing.out, .in, .inOut, .linear] {
            for u in stride(from: 0.0, through: 1.0, by: 0.1) {
                let back = FigureTimeline.ease(u, easing.reversed)
                #expect(abs(back - (1 - FigureTimeline.ease(1 - u, easing))) < 1e-9)
            }
        }
    }

    @Test("Looped cycle: enter, hold, action, hold, exit — ends hidden with a pause", arguments: [
        FigureEntrance.climb, .spring,
    ])
    func loopCycle(entrance: FigureEntrance) {
        let single = FigureTimeline(action: .wave, entrance: entrance, reduceMotion: false)
        let looped = FigureTimeline(
            action: .wave, entrance: entrance, reduceMotion: false, variation: loopVariation(repeats: 3, exit: entrance)
        )
        let enter = FigureTimeline.entranceDuration(entrance)
        #expect(abs(looped.duration - (single.duration + 0.7 + 1.1 + enter)) < 1e-9)
        #expect(looped.final == FigureTimeline.hiddenPose(entrance))
        #expect(looped.hiddenPause == 2)
        // Standing still during both holds.
        #expect(looped.joints(at: enter + 0.35) == .rest)
        #expect(looped.joints(at: looped.duration - enter - 0.5) == .rest)
        #expect(single.hiddenPause == nil)
    }

    @Test("Repeat count changes the action's beats", arguments: [
        (FigureAction.wave, 0.4), (.jumpingJacks, 0.6), (.march, 0.8), (.wormWalk, 0.76), (.handstand, 0.64),
        (.run, 0.66), (.rest, 0.48), (.sideStretch, 2.9),
    ])
    func repeatCount(action: FigureAction, beat: Double) {
        func length(_ repeats: Int) -> Double {
            FigureTimeline(
                action: action, entrance: nil, reduceMotion: false,
                variation: FigureVariation(repeats: repeats)
            ).duration
        }
        #expect(abs(length(3) - length(2) - beat) < 1e-9)
    }

    @Test("Random variation stays inside its ranges")
    func randomVariation() {
        var generator = SystemRandomNumberGenerator()
        for action in [FigureAction.rest, .wave, .jumpingJacks, .sideStretch, .march, .wormWalk, .handstand, .run] {
            for _ in 0..<50 {
                let v = FigureVariation.random(for: action, exit: .spring, using: &generator)
                #expect(FigureVariation.holdBeforeRange.contains(v.holdBefore))
                #expect(FigureVariation.holdAfterRange.contains(v.holdAfter))
                #expect(FigureVariation.hiddenPauseRange.contains(v.hiddenPause))
                #expect(FigureVariation.tempoScaleRange.contains(v.tempoScale))
                #expect(FigureVariation.repeatRange(action).contains(v.repeats ?? -1))
                #expect(v.exit == .spring)
            }
        }
    }

    @Test("Reduce Motion ignores the loop variation")
    func loopReduceMotion() {
        let timeline = FigureTimeline(
            action: .wave, entrance: .climb, reduceMotion: true, variation: loopVariation(repeats: 4)
        )
        #expect(timeline.duration == 0.2)
        #expect(timeline.hiddenPause == nil)
    }

    // MARK: - Random actions

    @Test("Random action: from the top repertoire, never the same twice in a row")
    func repertoire() {
        var generator = SystemRandomNumberGenerator()
        var previous: FigureAction?
        for _ in 0..<200 {
            let next = FigureRepertoire.next(after: previous, using: &generator)
            #expect(FigureRepertoire.top.contains(next))
            #expect(next != previous)
            previous = next
        }
        #expect(FigureRepertoire.next(after: .wave, from: [.wave], using: &generator) == .wave)
        #expect(FigureRepertoire.next(after: nil, from: [], using: &generator) == .rest)
    }

    // MARK: - Still windows

    @Test("Still windows: the holds of a looped cycle, never the walk")
    func stillWindows() {
        let looped = FigureTimeline(
            action: .wave, entrance: .spring, reduceMotion: false, variation: loopVariation(repeats: 2, exit: .spring)
        )
        let windows = looped.stillWindows
        #expect(windows.count == 2)
        #expect(windows.allSatisfy { $0.upperBound - $0.lowerBound >= 0.7 - 1e-9 })
        for window in windows {
            #expect(looped.joints(at: window.lowerBound) == looped.joints(at: window.upperBound))
            #expect(looped.joints(at: (window.lowerBound + window.upperBound) / 2) == .rest)
        }
        let walk = FigureTimeline(
            action: .wormWalk, entrance: .spring, reduceMotion: false, variation: loopVariation(repeats: 2, exit: .spring)
        )
        let window = walk.walkWindow!
        #expect(walk.stillWindows.allSatisfy { !($0.lowerBound < window.upperBound && $0.upperBound > window.lowerBound) })
        #expect(FigureTimeline(action: .wave, entrance: .spring, reduceMotion: true).stillWindows.isEmpty)
    }

    // MARK: - Anchors

    private let viewport = CGRect(x: 0, y: 100, width: 400, height: 600)

    private func eligible(_ rect: CGRect) -> Bool {
        FigureAnchorPicker.isEligible(rect: rect, viewport: viewport, figureHeight: 44, minWidth: 108)
    }

    @Test("Anchor eligibility: wide enough, head under the top, edge above the bottom, fully across")
    func anchorEligibility() {
        #expect(eligible(CGRect(x: 16, y: 300, width: 368, height: 200)))
        // Too narrow.
        #expect(!eligible(CGRect(x: 16, y: 300, width: 100, height: 200)))
        #expect(eligible(CGRect(x: 16, y: 300, width: 108, height: 200)))
        // Head would be under the top bar.
        #expect(!eligible(CGRect(x: 16, y: 140, width: 368, height: 200)))
        #expect(eligible(CGRect(x: 16, y: 144, width: 368, height: 200)))
        // Edge under the tab bar.
        #expect(!eligible(CGRect(x: 16, y: 690, width: 368, height: 200)))
        #expect(eligible(CGRect(x: 16, y: 676, width: 368, height: 200)))
        // Paged off to the side.
        #expect(!eligible(CGRect(x: 380, y: 300, width: 368, height: 200)))
        // Unbounded: only the width counts.
        #expect(FigureAnchorPicker.isEligible(
            rect: CGRect(x: -500, y: -500, width: 200, height: 10), viewport: nil, figureHeight: 44, minWidth: 108
        ))
    }

    @Test("Next anchor: another eligible one, the same only when alone, nil when none")
    func nextAnchor() {
        var generator = SystemRandomNumberGenerator()
        let a = (id: "a", rect: CGRect(x: 16, y: 300, width: 368, height: 100))
        let b = (id: "b", rect: CGRect(x: 16, y: 450, width: 368, height: 100))
        let off = (id: "off", rect: CGRect(x: 16, y: 900, width: 368, height: 100))
        func next(_ current: String?, _ candidates: [(id: String, rect: CGRect)]) -> String? {
            FigureAnchorPicker.next(
                current: current, candidates: candidates, viewport: viewport,
                figureHeight: 44, minWidth: 108, using: &generator
            )
        }
        for _ in 0..<50 {
            #expect(next("a", [a, b, off]) == "b")
            #expect(next("b", [a, b, off]) == "a")
            #expect(["a", "b"].contains(next(nil, [a, b, off])))
        }
        #expect(next("a", [a, off]) == "a")
        #expect(next("off", [a, off]) == "a")
        #expect(next("a", [off]) == nil)
        #expect(next(nil, []) == nil)
    }

    // MARK: - Bottom and side edges (phase 3B, canvas S_ludzik_krawedzie)

    private static let edgeActions: [(FigureAction, FigureEdge)] = [
        (.rest, .bottom), (.swing, .bottom), (.pullUp, .bottom),
        (.rest, .trailing), (.peek, .trailing), (.flag, .trailing), (.climb, .trailing), (.peek, .leading),
    ]

    private func points(_ joints: FigureJoints) -> [CGPoint] {
        let s = FigureSkeleton(joints)
        return [s.hip, s.torsoTop, s.head] + s.armL + s.armR + s.legL + s.legR
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    @Test("Edge actions start and end in their edge's rest", arguments: edgeActions)
    func edgeActionsRest(action: FigureAction, edge: FigureEdge) {
        let timeline = FigureTimeline(action: action, entrance: nil, reduceMotion: false, edge: edge)
        let rest = FigureTimeline.restPose(edge)
        #expect(timeline.keyframes.first?.joints == rest)
        #expect(timeline.final == rest)
        #expect(timeline.duration > 0.4)
    }

    @Test("Edge entrance comes out from hidden, the exit goes back", arguments: [FigureEdge.bottom, .trailing])
    func edgeEntranceAndExit(edge: FigureEdge) {
        var variation = FigureVariation.standard
        variation.exit = .climb
        variation.hiddenPause = 1
        let timeline = FigureTimeline(
            action: .rest, entrance: .climb, reduceMotion: false, edge: edge, variation: variation
        )
        let hidden = FigureTimeline.hiddenPose(.climb, edge: edge)
        #expect(timeline.keyframes.first?.joints == hidden)
        #expect(timeline.final == hidden)
        #expect(timeline.keyframes.contains { $0.joints == FigureTimeline.restPose(edge) })
    }

    @Test("Hidden edge poses stay entirely behind the card")
    func hiddenEdgePoses() {
        let reach = FigureSkeleton.limbWidth / 2 + 0.5
        // Bottom: everything above the card's bottom edge (and the head's radius).
        for point in points(FigureEdgePoses.hangHidden) {
            #expect(point.y + FigureSkeleton.headRadius < FigureEdgePoses.bottomEdgeY)
        }
        // Side: everything left of what the side box draws (behind the card).
        for point in points(FigureEdgePoses.sideHidden) {
            #expect(point.x + max(reach, FigureSkeleton.headRadius) < FigureEdgePoses.sideMaskX)
        }
        #expect(extent(FigureEdgePoses.sideHidden).maxX < PeekingFigureMetrics.sideBox.minX)
    }

    @Test("Hands keep their grip on the edge while hanging, pulling up and swinging")
    func bottomGrips() {
        let hang = FigureSkeleton(FigureEdgePoses.hang)
        let grips = [hang.armL[2], hang.armR[2]]
        #expect(abs(grips[0].y - (FigureEdgePoses.bottomEdgeY + 1.6)) < 0.5)
        for pose in [FigureEdgePoses.pullMid, FigureEdgePoses.pullTop, FigureEdgePoses.swingLeft, FigureEdgePoses.swingRight] {
            let s = FigureSkeleton(pose)
            #expect(distance(s.armL[2], grips[0]) < 0.6)
            #expect(distance(s.armR[2], grips[1]) < 0.6)
        }
    }

    @Test("Flag holds the side edge with both hands, body outside the card; peek with one, beside the card")
    func sideGrips() {
        for pose in [FigureEdgePoses.flagA, FigureEdgePoses.flagB] {
            let s = FigureSkeleton(pose)
            #expect(abs(s.armL[2].x - (FigureEdgePoses.sideEdgeX - 2.5)) < 0.6)
            #expect(abs(s.armR[2].x - (FigureEdgePoses.sideEdgeX - 2.5)) < 0.6)
            // Hips and feet past the edge: the flag sticks out of the card.
            #expect(s.hip.x > FigureEdgePoses.sideEdgeX + 20)
            #expect(s.legL[2].x > s.hip.x && s.legR[2].x > s.hip.x)
            // Body flat: torso horizontal.
            #expect(abs(s.hip.y - s.torsoTop.y) < 0.5)
        }
        let peek = FigureSkeleton(FigureEdgePoses.peek)
        #expect(distance(peek.armL[2], FigureEdgePoses.peekGrip) < 1e-6)
        #expect(peek.head.x - FigureSkeleton.headRadius > FigureEdgePoses.sideEdgeX)
        // Climb: the hip outside the card, facing it.
        #expect(FigureSkeleton(FigureEdgePoses.climbA).hip.x > FigureEdgePoses.sideEdgeX)
        #expect(FigureEdgePoses.climbA.facing == -1)
    }

    @Test("Climb travels along the edge; the other edge actions stay put")
    func climbTravels() {
        let climb = FigureTimeline(action: .climb, entrance: nil, reduceMotion: false, edge: .trailing)
        #expect(climb.walkWindow != nil)
        for action in [FigureAction.swing, .pullUp, .peek, .flag] {
            let edge: FigureEdge = action == .swing || action == .pullUp ? .bottom : .trailing
            #expect(FigureTimeline(action: action, entrance: nil, reduceMotion: false, edge: edge).walkWindow == nil)
        }
    }

    @Test("Relocating to another edge jumps to that edge's hidden pose while out of sight")
    func relocationAcrossEdges() throws {
        let timeline = FigureTimeline(
            action: .swing, entrance: .climb, reduceMotion: false, edge: .bottom, relocating: true, from: .top
        )
        let jump = try #require(timeline.relocatesAt)
        #expect(timeline.joints(at: 0) == .rest)
        #expect(timeline.joints(at: jump) == FigureTimeline.duckPose(.top))
        #expect(timeline.joints(at: jump + 0.001) == FigureEdgePoses.hangHidden)
        #expect(timeline.final == FigureEdgePoses.hang)
    }

    @Test("Each edge draws from its own repertoire")
    func edgeRepertoires() {
        var generator = SystemRandomNumberGenerator()
        for edge in FigureEdge.allCases {
            let actions = FigureRepertoire.actions(for: edge)
            for _ in 0..<20 {
                #expect(actions.contains(FigureRepertoire.next(after: nil, from: actions, using: &generator)))
            }
        }
        #expect(FigureRepertoire.actions(for: .leading) == FigureRepertoire.actions(for: .trailing))
    }

    private let sizes = FigureSizes(
        figureHeight: 56, minWidth: 108, hangHeight: 49, sideMinHeight: 82, climbMinHeight: 136, screenEdgeGap: 28
    )

    @Test("Bottom and side eligibility: hang above the tab bar, side tall enough on screen")
    func edgeEligibility() {
        func ok(_ rect: CGRect, _ edge: FigureEdge) -> Bool {
            FigureAnchorPicker.isEligible(rect: rect, edge: edge, viewport: viewport, sizes: sizes)
        }
        // Clear of the screen's edges, so the sides take the full repertoire.
        let card = CGRect(x: 40, y: 300, width: 320, height: 120)
        for edge in FigureEdge.allCases { #expect(ok(card, edge)) }
        // Bottom: the hang would reach under the tab bar.
        #expect(!ok(CGRect(x: 16, y: 560, width: 368, height: 100), .bottom))
        #expect(ok(CGRect(x: 16, y: 500, width: 368, height: 100), .bottom))
        // Bottom edge scrolled above the top.
        #expect(!ok(CGRect(x: 16, y: -100, width: 368, height: 210), .bottom))
        // Side: too short a card, or too little of it on screen.
        #expect(!ok(CGRect(x: 16, y: 300, width: 368, height: 60), .trailing))
        #expect(!ok(CGRect(x: 40, y: 640, width: 320, height: 300), .leading))
        #expect(ok(CGRect(x: 40, y: 600, width: 320, height: 300), .leading))
    }

    @Test("Flag: a human flag — grips wide apart on the edge, upper arm straight, arms never crossed")
    func flagGrips() {
        let top = FigureEdgePoses.flagGripTop, bottom = FigureEdgePoses.flagGripBottom
        #expect(bottom.y - top.y >= 25)
        #expect(top.x == FigureEdgePoses.sideGripX && bottom.x == FigureEdgePoses.sideGripX)
        let flag = FigureTimeline(action: .flag, entrance: nil, reduceMotion: false, edge: .trailing)
        for time in samples(flag) {
            let s = FigureSkeleton(flag.joints(at: time))
            let flagPoses = [FigureEdgePoses.flagSwing, FigureEdgePoses.flagA, FigureEdgePoses.flagB]
            guard let (a, b) = segment(flag, at: time), flagPoses.contains(a.joints), flagPoses.contains(b.joints)
            else { continue }
            // The upper hand is the upper arm's (`R`), the lower the lower's.
            #expect(distance(s.armR[2], top) < 0.6 && distance(s.armL[2], bottom) < 0.6, "at \(time)")
            #expect(s.armR[0].y < s.armL[0].y)
            // Not crossed: the upper arm's elbow stays above the lower arm's.
            #expect(s.armR[1].y < s.armL[1].y)
        }
        for pose in [FigureEdgePoses.flagA, FigureEdgePoses.flagB] {
            // Pulling on a straight upper arm.
            #expect(abs(pose.elbowR) < 1e-6)
        }
    }

    @Test("Edge weights: 25% each; renormalized; top only when asked")
    func edgeWeights() {
        var generator = SystemRandomNumberGenerator()
        let card = (id: "a", rect: CGRect(x: 40, y: 300, width: 320, height: 120), edges: FigureEdges.all)
        var counts: [FigureEdge: Int] = [:]
        let draws = 6000
        for _ in 0..<draws {
            let pick = FigureAnchorPicker.nextPlacement(
                current: nil, candidates: [card], viewport: viewport, sizes: sizes, using: &generator
            )
            counts[pick!.edge, default: 0] += 1
        }
        func share(_ edge: FigureEdge) -> Double { Double(counts[edge, default: 0]) / Double(draws) }
        for edge in [FigureEdge.top, .bottom, .leading, .trailing] {
            #expect(abs(share(edge) - 0.25) < 0.04)
        }

        // Without the top: a third each.
        let noTop = (id: "a", rect: card.rect, edges: FigureEdges([.bottom, .leading, .trailing]))
        var bottoms = 0
        for _ in 0..<draws {
            let pick = FigureAnchorPicker.nextPlacement(
                current: nil, candidates: [noTop], viewport: viewport, sizes: sizes, using: &generator
            )
            if pick?.edge == .bottom { bottoms += 1 }
        }
        #expect(abs(Double(bottoms) / Double(draws) - 1.0 / 3) < 0.04)

        // Not looping: only the top.
        for _ in 0..<50 {
            let pick = FigureAnchorPicker.nextPlacement(
                current: nil, candidates: [card], viewport: viewport, sizes: sizes, allowed: .top, using: &generator
            )
            #expect(pick?.edge == .top)
        }
        // Another anchor wins over the current one, whatever the edge.
        let other = (id: "b", rect: CGRect(x: 16, y: 450, width: 368, height: 120), edges: FigureEdges.bottom)
        for _ in 0..<50 {
            let pick = FigureAnchorPicker.nextPlacement(
                current: "a", candidates: [card, other], viewport: viewport, sizes: sizes, using: &generator
            )
            #expect(pick?.id == "b" && pick?.edge == .bottom)
        }
    }

    @Test("Side placement keeps the box between the margins of the track")
    func sidePlacement() {
        let track: ClosedRange<CGFloat> = 100...300
        #expect(FigurePlacement.sideTop(fraction: 0, track: track, boxHeight: 58, margin: 12) == 112)
        #expect(abs(FigurePlacement.sideTop(fraction: 1, track: track, boxHeight: 58, margin: 12) - 230) < 0.001)
        #expect(abs(FigurePlacement.sideTop(fraction: 2, track: track, boxHeight: 58, margin: 12) - 230) < 0.001)
    }

    // MARK: - Grips, climb, worm walk, handstand

    /// Every ~1/60 s of `timeline`.
    private func samples(_ timeline: FigureTimeline) -> [Double] {
        Array(stride(from: 0, through: timeline.duration, by: 1.0 / 60))
    }

    /// The segment of `timeline` that `time` falls in (its two keyframes).
    private func segment(
        _ timeline: FigureTimeline, at time: Double
    ) -> (FigureTimeline.Keyframe, FigureTimeline.Keyframe)? {
        zip(timeline.keyframes, timeline.keyframes.dropFirst()).first { time > $0.time && time <= $1.time }
    }

    /// Everything drawn — joints widened by the stroke caps, the head by its
    /// radius — as one box in grid units.
    private func extent(_ joints: FigureJoints) -> CGRect {
        let s = FigureSkeleton(joints)
        let limbs = s.armL + s.armR + s.legL + s.legR + [s.hip, s.torsoTop]
        let cap = FigureSkeleton.limbWidth / 2, r = FigureSkeleton.headRadius
        var box = CGRect(origin: limbs[0], size: .zero)
        for point in limbs { box = box.union(CGRect(x: point.x - cap, y: point.y - cap, width: 2 * cap, height: 2 * cap)) }
        // The torso is wider than the limbs.
        let torso = FigureSkeleton.torsoWidth / 2
        for point in [s.hip, s.torsoTop] {
            box = box.union(CGRect(x: point.x - torso, y: point.y - torso, width: 2 * torso, height: 2 * torso))
        }
        return box.union(CGRect(x: s.head.x - r, y: s.head.y - r, width: 2 * r, height: 2 * r))
    }

    @Test("IK: a hand reaches its target, keeps its elbow side, straightens out of reach")
    func ikPlacing() {
        let target = CGPoint(x: 70, y: 30)
        let placed = FigureJoints.rest.placing(.armR, at: target)
        #expect(distance(FigureSkeleton(placed).armR[2], target) < 1e-6)
        #expect(placed.elbowR < 0)
        let far = FigureJoints.rest.placing(.armR, at: CGPoint(x: 99, y: 46))
        #expect(abs(far.elbowR) < 1e-6)
        // Mirrored figures solve as drawn.
        let mirrored = FigureEdgePoses.climbA.placing(.legL, at: CGPoint(x: 100, y: 90))
        #expect(distance(FigureSkeleton(mirrored).legL[2], CGPoint(x: 100, y: 90)) < 1e-6)
    }

    @Test("Bottom: both hands stay on their grips through the entrance, rest, swing, pull-up and exit")
    func bottomGripsSampled() {
        let hang = FigureSkeleton(FigureEdgePoses.hang)
        let grips = [hang.armL[2], hang.armR[2]]
        var variation = FigureVariation.standard
        variation.exit = .climb
        variation.hiddenPause = 1
        for action in [FigureAction.rest, .swing, .pullUp] {
            let timeline = FigureTimeline(
                action: action, entrance: .climb, reduceMotion: false, edge: .bottom, variation: variation
            )
            for time in samples(timeline) {
                let s = FigureSkeleton(timeline.joints(at: time))
                // Never crossed.
                #expect(s.armL[2].x < s.armR[2].x)
                guard let (a, b) = segment(timeline, at: time), b.limbs == FigureEdgePoses.hangGrips else { continue }
                // On the grip line all the time, on the grips whenever both ends hang there.
                #expect(abs(s.armL[2].x - grips[0].x) < 0.6 && abs(s.armR[2].x - grips[1].x) < 0.6)
                let ends = [FigureSkeleton(a.joints), FigureSkeleton(b.joints)]
                if ends.allSatisfy({ distance($0.armL[2], grips[0]) < 0.6 && distance($0.armR[2], grips[1]) < 0.6 }) {
                    #expect(distance(s.armL[2], grips[0]) < 0.6, "armL at \(time)")
                    #expect(distance(s.armR[2], grips[1]) < 0.6, "armR at \(time)")
                }
            }
        }
        // Ducking from the bottom: the hands slide up the grip line.
        let duck = FigureTimeline(
            action: .wave, entrance: .spring, reduceMotion: false, edge: .top, relocating: true, from: .bottom
        )
        for time in stride(from: 0.0, through: FigureTimeline.duckDuration, by: 1.0 / 60) {
            let s = FigureSkeleton(duck.joints(at: time))
            #expect(abs(s.armL[2].x - grips[0].x) < 0.6 && abs(s.armR[2].x - grips[1].x) < 0.6)
        }
    }

    @Test("Bottom: bent arms always bend outward — a wide-grip hang, swing and pull-up")
    func bottomElbowsOutward() {
        var variation = FigureVariation.standard
        variation.exit = .climb
        variation.hiddenPause = 1
        /// How far `elbow` lies to the right of the line from `shoulder` to `hand` (grid units).
        func rightOfLine(_ chain: [CGPoint]) -> Double {
            let (shoulder, elbow, hand) = (chain[0], chain[1], chain[2])
            let t = (elbow.y - shoulder.y) / (hand.y - shoulder.y)
            return elbow.x - (shoulder.x + (hand.x - shoulder.x) * t)
        }
        var bentSamples = 0
        for action in [FigureAction.rest, .swing, .pullUp] {
            let timeline = FigureTimeline(
                action: action, entrance: .climb, reduceMotion: false, edge: .bottom, variation: variation
            )
            for time in samples(timeline) {
                let joints = timeline.joints(at: time)
                let s = FigureSkeleton(joints)
                if abs(joints.elbowL) > 15 {
                    bentSamples += 1
                    #expect(rightOfLine(s.armL) < 0 && s.armL[1].x < s.armL[0].x, "\(action) armL at \(time)")
                }
                if abs(joints.elbowR) > 15 {
                    #expect(rightOfLine(s.armR) > 0 && s.armR[1].x > s.armR[0].x, "\(action) armR at \(time)")
                }
            }
        }
        #expect(bentSamples > 20)
        for pose in [FigureEdgePoses.pullMid, FigureEdgePoses.pullTop, FigureEdgePoses.swingLeft, FigureEdgePoses.swingRight] {
            let s = FigureSkeleton(pose)
            #expect(rightOfLine(s.armL) <= 0.01 && rightOfLine(s.armR) >= -0.01)
        }
        let top = FigureSkeleton(FigureEdgePoses.pullTop)
        #expect(top.armL[1].x < top.armL[0].x && top.armR[1].x > top.armR[0].x)
    }

    @Test("Side: held hands stay put through the peek and the flag")
    func sideGripsSampled() {
        for action in [FigureAction.rest, .peek, .flag] {
            let timeline = FigureTimeline(action: action, entrance: nil, reduceMotion: false, edge: .trailing)
            for time in samples(timeline) {
                guard let (a, b) = segment(timeline, at: time), !b.limbs.isEmpty else { continue }
                let s = FigureSkeleton(timeline.joints(at: time))
                for limb in FigureLimb.allCases where b.limbs[limb] == .held {
                    // Grips that stay put; the others move along a line on purpose
                    // (a hand sliding down the edge to the flag's grip).
                    let start = FigureSkeleton(a.joints).end(of: limb)
                    guard distance(start, FigureSkeleton(b.joints).end(of: limb)) < 0.6 else { continue }
                    #expect(distance(s.end(of: limb), start) < 0.6, "\(limb) at \(time)")
                    #expect(abs(s.end(of: limb).x - FigureEdgePoses.sideGripX) < 0.6)
                }
            }
        }
    }

    @Test("Climb: outside the card, facing it, hand over hand; held hands and feet stay put on the card")
    func climbOutside() throws {
        let climb = FigureTimeline(action: .climb, entrance: nil, reduceMotion: false, edge: .trailing)
        let distanceUp = try #require(climb.walkDistance)
        #expect(abs(distanceUp - 2 * 3 * FigureEdgePoses.climbReach) < 1e-9)
        #expect(FigureTimeline.travel(.climb, repeats: 3) == climb.walkDistance)
        // Climbing poses: hands on the edge, feet on it, hip past it, in profile facing the card.
        for pose in [FigureEdgePoses.climbA, FigureEdgePoses.climbB] {
            let s = FigureSkeleton(pose)
            #expect(abs(s.armL[2].x - FigureEdgePoses.sideGripX) < 1e-6 && abs(s.armR[2].x - FigureEdgePoses.sideGripX) < 1e-6)
            #expect(abs(s.legL[2].x - FigureEdgePoses.climbFootX) < 1e-6)
            #expect(s.hip.x > FigureEdgePoses.sideEdgeX + 5)
            #expect(pose.profile == 1 && pose.facing == -1)
            let box = extent(pose)
            #expect(box.minY >= 0 && box.maxY <= PeekingFigureMetrics.sideBox.height)
            #expect(box.maxX <= 2 * PeekingFigureMetrics.sideBox.width)
        }
        #expect(climb.keyframes.first?.joints == FigureEdgePoses.peek)
        #expect(climb.final == FigureEdgePoses.peek)
        // A held limb stays at one spot on the card: its grid y minus the
        // distance risen so far is constant over its segment.
        for time in samples(climb) {
            guard let (a, b) = segment(climb, at: time), b.travel > 0 else { continue }
            let s = FigureSkeleton(climb.joints(at: time))
            let risen = try #require(climb.walkProgress(at: time)) * distanceUp
            let risenAtStart = try #require(climb.walkProgress(at: a.time)) * distanceUp
            for limb in FigureLimb.allCases where b.limbs[limb] == .held {
                let start = FigureSkeleton(a.joints).end(of: limb)
                #expect(abs((s.end(of: limb).y - risen) - (start.y - risenAtStart)) < 0.6, "\(limb) at \(time)")
                #expect(abs(s.end(of: limb).x - start.x) < 0.6)
            }
        }
    }

    @Test("Side actions play outside the card: torso and head beside it, only the grips over the edge",
          arguments: [FigureAction.rest, .peek, .flag, .climb])
    func sideOutside(action: FigureAction) {
        let timeline = FigureTimeline(action: action, entrance: nil, reduceMotion: false, edge: .trailing)
        for time in samples(timeline) {
            let s = FigureSkeleton(timeline.joints(at: time))
            #expect(s.hip.x > FigureEdgePoses.sideEdgeX && s.torsoTop.x > FigureEdgePoses.sideEdgeX, "torso at \(time)")
            #expect(s.head.x > FigureEdgePoses.sideEdgeX, "head at \(time)")
            // Elbows, knees and feet stay near or past the edge; hands may wrap it.
            for point in [s.armL[1], s.armR[1], s.legL[1], s.legR[1], s.legL[2], s.legR[2], s.armL[2], s.armR[2]] {
                #expect(point.x >= FigureEdgePoses.sideMaskX + 1.5, "limb at \(time)")
            }
            let box = extent(timeline.joints(at: time))
            #expect(box.minY >= 0 && box.maxY <= PeekingFigureMetrics.sideBox.maxY, "y at \(time)")
            #expect(box.maxX <= PeekingFigureMetrics.sideBox.maxX, "x at \(time)")
        }
    }

    @Test("Side entrance slides out from behind the card's edge, the exit slides back")
    func sideEntrance() {
        var variation = FigureVariation.standard
        variation.exit = .spring
        let timeline = FigureTimeline(
            action: .peek, entrance: .spring, reduceMotion: false, edge: .trailing, variation: variation
        )
        #expect(extent(timeline.keyframes[0].joints).maxX < FigureEdgePoses.sideMaskX)
        #expect(extent(timeline.final).maxX < FigureEdgePoses.sideMaskX)
        #expect(FigureTimeline.duckPose(.trailing) == FigureEdgePoses.sideHidden)
    }

    @Test("Climb goes up: it starts low on the side and ends a climb's distance higher")
    func climbGoesUp() throws {
        let metrics = PeekingFigureMetrics.standard
        let card = CGRect(x: 16, y: 200, width: 368, height: 300)
        let span = metrics.travelSpan(at: .trailing, on: card)
        let range = metrics.spotRange(at: .trailing, on: card, viewport: viewport)
        let room = metrics.travelRoom(at: .trailing, on: card, viewport: viewport, from: nil)
        let climb = try #require(FigureTimeline.travel(.climb, repeats: 3))
        #expect(room >= climb)
        let start = range.upperBound
        let target = FigurePlacement.travelTarget(from: start, distance: climb, direction: -1, scale: metrics.scale, span: span)
        #expect(target < start)
        #expect(target >= range.lowerBound)
        // The box rises exactly the climb's distance in points.
        func top(_ fraction: Double) -> CGFloat {
            FigurePlacement.sideTop(
                fraction: fraction, track: card.minY...card.maxY,
                boxHeight: metrics.size(for: .trailing).height, margin: metrics.sideMargin
            )
        }
        #expect(abs((top(start) - top(target)) - CGFloat(climb) * metrics.scale) < 0.01)
    }

    @Test("Climb is offered only where the side on screen is tall enough for it")
    func climbNeedsRoom() throws {
        let metrics = PeekingFigureMetrics.standard
        let sizes = metrics.sizes
        let minimum = try #require(FigureTimeline.minimumTravel(.climb))
        #expect(abs(minimum - 2 * 2 * FigureEdgePoses.climbReach) < 1e-9)
        #expect(sizes.climbMinHeight == 136)
        func actions(height: CGFloat) -> [FigureAction] {
            let card = CGRect(x: 16, y: 200, width: 368, height: height)
            let room = metrics.travelRoom(at: .trailing, on: card, viewport: viewport, from: nil)
            return FigureRepertoire.actions(for: .trailing, room: room)
        }
        #expect(actions(height: sizes.climbMinHeight).contains(.climb))
        #expect(actions(height: sizes.climbMinHeight + 40).contains(.climb))
        // Tall enough for the flag, not for the climb.
        #expect(actions(height: sizes.climbMinHeight - 2) == [.flag])
        #expect(FigureAnchorPicker.isEligible(
            rect: CGRect(x: 40, y: 200, width: 320, height: sizes.climbMinHeight - 2),
            edge: .trailing, viewport: viewport, sizes: sizes
        ))
        // A tall card mostly off screen: only what shows counts.
        let tall = CGRect(x: 16, y: 600, width: 368, height: 600)
        let room = metrics.travelRoom(at: .trailing, on: tall, viewport: viewport, from: nil)
        #expect(!FigureRepertoire.actions(for: .trailing, room: room).contains(.climb))
        // Bottom: nothing travels.
        #expect(FigureRepertoire.actions(for: .bottom, room: 0) == FigureRepertoire.bottom)
        // Narrow tops drop the worm walk.
        #expect(!FigureRepertoire.actions(for: .top, room: 10).contains(.wormWalk))
        #expect(FigureRepertoire.actions(for: .top, room: 1000) == FigureRepertoire.top)
    }

    @Test("Worm walk and handstand stay inside the top's box, never below the edge", arguments: [
        FigureAction.wormWalk, .handstand,
    ])
    func topFloorWorkInBox(action: FigureAction) {
        for repeats in FigureVariation.repeatRange(action) {
            let timeline = FigureTimeline(
                action: action, entrance: nil, reduceMotion: false, variation: FigureVariation(repeats: repeats)
            )
            for time in samples(timeline) {
                let joints = timeline.joints(at: time)
                // Travelling left the stage mirrors it around the box's middle.
                let mirrored = joints.with { $0.facing = 1 - 2 * $0.profile; $0.x *= $0.facing }
                for box in [extent(joints), extent(mirrored)] {
                    #expect(box.minX >= -0.3 && box.maxX <= FigureSkeleton.peekBox.width + 0.3, "x \(box) at \(time)")
                    #expect(box.minY >= 0 && box.maxY <= FigureSkeleton.edgeY + 0.3, "y \(box) at \(time)")
                }
            }
        }
    }

    @Test("Worm walk: lies flat in profile; held hands and feet stay put on the card")
    func wormHolds() throws {
        let flat = FigureSkeleton(FigureEdgePoses.wormFlat)
        #expect(FigureEdgePoses.wormFlat.profile == 1)
        #expect(abs(flat.hip.y - flat.torsoTop.y) < 0.5)
        let worm = FigureTimeline(action: .wormWalk, entrance: nil, reduceMotion: false)
        let distanceWalked = try #require(worm.walkDistance)
        for time in samples(worm) {
            guard let (a, b) = segment(worm, at: time), !b.limbs.isEmpty else { continue }
            let s = FigureSkeleton(worm.joints(at: time))
            let walked = try #require(worm.walkProgress(at: time)) * distanceWalked
            let walkedAtStart = try #require(worm.walkProgress(at: a.time)) * distanceWalked
            for limb in FigureLimb.allCases where b.limbs[limb] == .held {
                let start = FigureSkeleton(a.joints).end(of: limb)
                // Grips and planted feet; the rest of `.held` slides on purpose
                // (the legs stretching back to lie down).
                let end = FigureSkeleton(b.joints).end(of: limb)
                guard b.travel > 0 || distance(start, end) < 0.6 else { continue }
                #expect(abs((s.end(of: limb).x + walked) - (start.x + walkedAtStart)) < 0.6, "\(limb) at \(time)")
                #expect(abs(s.end(of: limb).y - start.y) < 0.6)
            }
        }
    }

    @Test("Handstand: upside down on straight arms, hands on the edge, held through the wobble")
    func handstandPose() {
        let s = FigureSkeleton(FigureEdgePoses.handstand)
        for hand in [s.armL[2], s.armR[2]] {
            #expect(abs(hand.y - FigureEdgePoses.groundY) < 1e-6)
        }
        #expect(s.legL[2].y < s.hip.y && s.hip.y < s.torsoTop.y)
        let timeline = FigureTimeline(action: .handstand, entrance: nil, reduceMotion: false)
        let grips = [s.armL[2], s.armR[2]]
        for time in samples(timeline) {
            guard let (_, b) = segment(timeline, at: time), b.limbs == .hands else { continue }
            let pose = FigureSkeleton(timeline.joints(at: time))
            #expect(distance(pose.armL[2], grips[0]) < 0.6 && distance(pose.armR[2], grips[1]) < 0.6, "at \(time)")
        }
    }

    @Test("Appear delay: 1.5–3 s by default, scaled by tempo; 0...0 comes out at once")
    func appearDelay() {
        var generator = SystemRandomNumberGenerator()
        #expect(FigureStyle.standard.appearDelay == 1.5...3.0)
        for _ in 0..<50 {
            #expect((1.5...3.0).contains(FigureStyle.standard.entranceDelay(using: &generator)))
            #expect((0.75...1.5).contains(FigureStyle(tempo: 2).entranceDelay(using: &generator)))
        }
        #expect(FigureStyle(appearDelay: 0...0).entranceDelay(using: &generator) == 0)
        #expect(FigureStyle(appearDelay: 1.5...1.5).entranceDelay(using: &generator) == 1.5)
    }

    // MARK: - No repeats

    @Test("500 plays in a row: never the same action twice, never the same anchor and edge twice, when there is another")
    func noRepeats() throws {
        var generator = SystemRandomNumberGenerator()
        let metrics = PeekingFigureMetrics.standard
        // Tall and short cards (climb or not), wide and narrow tops (worm or not).
        let pool: [(id: Int, rect: CGRect, edges: FigureEdges)] = [
            (0, CGRect(x: 16, y: 150, width: 368, height: 300), .all),
            (1, CGRect(x: 16, y: 300, width: 368, height: 100), [.leading, .trailing]),
            (2, CGRect(x: 16, y: 300, width: 120, height: 100), [.top, .trailing]),
            (3, CGRect(x: 16, y: 450, width: 368, height: 120), .bottom),
            (4, CGRect(x: 16, y: 300, width: 110, height: 90), .top),
        ]
        func actions(_ rect: CGRect, _ edge: FigureEdge) -> [FigureAction] {
            FigureRepertoire.actions(
                for: edge, room: metrics.travelRoom(at: edge, on: rect, viewport: viewport, from: nil)
            )
        }
        var current: (id: Int, edge: FigureEdge)?
        var previous: FigureAction?
        var plays = 0
        for _ in 0..<500 {
            // A random subset of the cards is laid out each time.
            let candidates = pool.filter { _ in Bool.random(using: &generator) }
            let last = previous
            guard let pick = FigureAnchorPicker.nextPlacement(
                current: current?.id, currentEdge: current?.edge, candidates: candidates, viewport: viewport,
                sizes: metrics.sizes,
                offersFresh: { _, rect, edge in actions(rect, edge).contains { $0 != last } },
                using: &generator
            ) else { continue }
            let rect = try #require(candidates.first { $0.id == pick.id }?.rect)
            let action = FigureRepertoire.next(after: previous, from: actions(rect, pick.edge), using: &generator)
            // Every place the stage could have picked.
            let places = candidates.flatMap { candidate in
                FigureEdge.allCases.filter {
                    candidate.edges.contains($0.member)
                        && FigureAnchorPicker.isEligible(rect: candidate.rect, edge: $0, viewport: viewport, sizes: metrics.sizes)
                }.map { (id: candidate.id, rect: candidate.rect, edge: $0) }
            }
            if places.contains(where: { place in actions(place.rect, place.edge).contains { $0 != previous } }) {
                #expect(action != previous)
            }
            if let current, places.contains(where: { $0.id != current.id || $0.edge != current.edge }) {
                #expect(pick.id != current.id || pick.edge != current.edge)
            }
            current = pick
            previous = action
            plays += 1
        }
        #expect(plays > 400)
        // Only the last action is possible: the repeat is allowed.
        #expect(FigureRepertoire.next(after: .swing, from: [.swing], using: &generator) == .swing)
    }

    // MARK: - Sides at the screen's edge

    @Test("A side at the screen's edge only climbs: a full-width card on both sides, a half-width tile on its outer side")
    func screenEdgeSides() {
        let metrics = PeekingFigureMetrics.standard
        let sizes = metrics.sizes
        #expect(sizes.screenEdgeGap == 28)
        #expect(PeekingFigureMetrics(height: 112).screenEdgeGap == 56)
        func actions(_ rect: CGRect, _ edge: FigureEdge) -> [FigureAction] {
            FigureRepertoire.actions(
                for: edge, room: metrics.travelRoom(at: edge, on: rect, viewport: viewport, from: nil),
                atScreenEdge: FigureAnchorPicker.isAtScreenEdge(
                    rect: rect, edge: edge, viewport: viewport, gap: sizes.screenEdgeGap
                )
            )
        }
        func ok(_ rect: CGRect, _ edge: FigureEdge) -> Bool {
            FigureAnchorPicker.isEligible(rect: rect, edge: edge, viewport: viewport, sizes: sizes)
        }
        // Full width (16…384 in a 400-wide viewport): both sides climb only.
        let full = CGRect(x: 16, y: 200, width: 368, height: 300)
        for edge in [FigureEdge.leading, .trailing] {
            #expect(FigureAnchorPicker.isAtScreenEdge(rect: full, edge: edge, viewport: viewport, gap: 28))
            #expect(actions(full, edge) == [.climb])
            #expect(ok(full, edge))
        }
        // A half-width tile (16…196): the outer side climbs only, the inner
        // one (facing its neighbour) takes everything.
        let tile = CGRect(x: 16, y: 200, width: 180, height: 300)
        #expect(actions(tile, .leading) == [.climb])
        #expect(actions(tile, .trailing) == FigureRepertoire.side)
        // At the screen's edge and too short to climb: not eligible at all;
        // the same height facing a neighbour still flags.
        let short = CGRect(x: 16, y: 200, width: 180, height: sizes.climbMinHeight - 10)
        #expect(!ok(short, .leading))
        #expect(ok(short, .trailing))
        #expect(actions(short, .trailing) == [.flag])
        #expect(ok(CGRect(x: 16, y: 200, width: 180, height: sizes.climbMinHeight), .leading))
        // A single card (no viewport) is never at the screen's edge.
        #expect(!FigureAnchorPicker.isAtScreenEdge(rect: full, edge: .trailing, viewport: nil, gap: 28))
        // Top and bottom never are.
        #expect(!FigureAnchorPicker.isAtScreenEdge(rect: full, edge: .top, viewport: viewport, gap: 28))
    }

    // MARK: - Climb entrance and exit

    /// No frame turns the figure by squashing it flat (facing through 0).
    private func neverSquashed(_ timeline: FigureTimeline) {
        for time in samples(timeline) {
            let joints = timeline.joints(at: time)
            #expect(abs(joints.facing) > 0.99, "facing \(joints.facing) at \(time)")
        }
    }

    @Test("Flipped facing draws the same figure")
    func flippedFacing() {
        for pose in [FigureEdgePoses.peek, FigureEdgePoses.peekOut, FigureJoints.rest] {
            let a = FigureSkeleton(pose), b = FigureSkeleton(pose.flippedFacing)
            #expect(distance(a.head, b.head) < 1e-6 && distance(a.torsoTop, b.torsoTop) < 1e-6)
            for i in 0..<3 {
                #expect(distance(a.armL[i], b.armR[i]) < 1e-6 && distance(a.armR[i], b.armL[i]) < 1e-6)
                #expect(distance(a.legL[i], b.legR[i]) < 1e-6 && distance(a.legR[i], b.legL[i]) < 1e-6)
            }
        }
    }

    @Test("Climb entrance: from behind the card, hands first, out in profile facing the card — no turn, no peek")
    func climbEntrance() throws {
        var variation = FigureVariation(repeats: 2)
        variation.exit = .climb
        variation.hiddenPause = 1
        let climb = FigureTimeline(action: .climb, entrance: .climb, reduceMotion: false, edge: .trailing, variation: variation)
        // Starts and ends fully behind the card.
        #expect(climb.keyframes[0].joints == FigureEdgePoses.climbHidden)
        #expect(climb.final == FigureEdgePoses.climbHidden)
        #expect(extent(FigureEdgePoses.climbHidden).maxX < FigureEdgePoses.sideMaskX)
        #expect(FigureEdgePoses.climbHidden.profile == 1 && FigureEdgePoses.climbHidden.facing == -1)
        // The entrance lands in `climbA`, never through the peek.
        let entered = FigureEdgePoses.climbEntranceSteps.map(\.duration).reduce(0, +)
        #expect(climb.keyframes.contains { abs($0.time - entered) < 1e-9 && $0.joints == FigureEdgePoses.climbA })
        #expect(!climb.keyframes.contains { $0.joints == FigureEdgePoses.peek })
        // Hands: the low one grips first, then the high one.
        let low = FigureSkeleton(FigureEdgePoses.climbReachLow)
        #expect(distance(low.armL[2], FigureEdgePoses.climbGripLow) < 1e-6)
        #expect(low.armR[2].x < FigureEdgePoses.sideMaskX)
        let high = FigureSkeleton(FigureEdgePoses.climbReachHigh)
        #expect(distance(high.armR[2], FigureEdgePoses.climbGripHigh) < 1e-6)
        // Gripping hands hold while the body swings out and back in.
        for time in samples(climb) {
            guard let (a, b) = segment(climb, at: time), b.travel == 0 else { continue }
            let s = FigureSkeleton(climb.joints(at: time))
            for limb in FigureLimb.allCases where b.limbs[limb] == .held {
                let start = FigureSkeleton(a.joints).end(of: limb)
                guard distance(start, FigureSkeleton(b.joints).end(of: limb)) < 0.6 else { continue }
                #expect(distance(s.end(of: limb), start) < 0.6, "\(limb) at \(time)")
            }
        }
        neverSquashed(climb)
        // Still goes up.
        #expect(try #require(climb.walkDistance) > 0)
    }

    @Test("Climb without entrance or exit turns from and back to the peek without squashing")
    func climbTurns() {
        let climb = FigureTimeline(action: .climb, entrance: nil, reduceMotion: false, edge: .trailing)
        #expect(climb.keyframes[0].joints == FigureEdgePoses.peek)
        #expect(climb.final == FigureEdgePoses.peek)
        neverSquashed(climb)
        // The turn's flipped peek is the peek, drawn the same.
        #expect(distance(
            FigureSkeleton(FigureEdgePoses.peek.flippedFacing).armR[2], FigureEdgePoses.peekGrip
        ) < 1e-6)
        // Coming out at the start, staying out at the end.
        let out = FigureTimeline(action: .climb, entrance: .climb, reduceMotion: false, edge: .trailing)
        #expect(out.keyframes[0].joints == FigureEdgePoses.climbHidden)
        #expect(out.final == FigureEdgePoses.peek)
        neverSquashed(out)
    }

    @Test("A tap mid-climb leaves around the edge in profile, hidden at the jump")
    func climbRelocation() throws {
        let timeline = FigureTimeline(
            action: .peek, entrance: .climb, reduceMotion: false, edge: .leading,
            relocating: true, from: .trailing, pose: FigureEdgePoses.climbB
        )
        let jump = try #require(timeline.relocatesAt)
        #expect(timeline.joints(at: 0) == FigureEdgePoses.climbB)
        #expect(timeline.keyframes.contains { abs($0.time - jump) < 1e-9 && $0.joints == FigureEdgePoses.climbHidden })
        for time in samples(timeline) where time <= jump { #expect(abs(timeline.joints(at: time).facing) > 0.99) }
        // Not climbing: the usual duck.
        let peek = FigureTimeline(
            action: .peek, entrance: .climb, reduceMotion: false, edge: .leading,
            relocating: true, from: .trailing, pose: FigureEdgePoses.peek
        )
        #expect(abs(try #require(peek.relocatesAt) - FigureTimeline.duckDuration) < 1e-9)
    }

    // MARK: - Flag entrance and exit

    @Test("Flag entrance: from behind the card, upper hand, lower hand, swing out flat — no peek, no turn")
    func flagEntrance() throws {
        var variation = FigureVariation(repeats: 2)
        variation.exit = .climb
        variation.hiddenPause = 1
        let flag = FigureTimeline(action: .flag, entrance: .climb, reduceMotion: false, edge: .trailing, variation: variation)
        let poses = FigureEdgePoses.self
        #expect(flag.keyframes[0].joints == poses.flagHidden)
        #expect(flag.final == poses.flagHidden)
        #expect(extent(poses.flagHidden).maxX < poses.sideMaskX)
        let entered = poses.flagEntranceSteps.map(\.duration).reduce(0, +)
        #expect(flag.keyframes.contains { abs($0.time - entered) < 1e-9 && $0.joints == poses.flagA })
        #expect(!flag.keyframes.contains { $0.joints == poses.peek })
        // The upper hand grips first (the lower one still behind the card), then the lower.
        let high = FigureSkeleton(poses.flagReachHigh)
        #expect(distance(high.armR[2], poses.flagGripTop) < 1e-6)
        #expect(high.armL[2].x < poses.sideMaskX)
        let low = FigureSkeleton(poses.flagReachLow)
        #expect(distance(low.armL[2], poses.flagGripBottom) < 1e-6)
        #expect(distance(low.armR[2], poses.flagGripTop) < 1e-6)
        // Exit: the lower hand lets go before the upper one.
        let exit = poses.flagRoute.exit
        #expect(exit.map(\.joints) == [poses.flagSwing, poses.flagReachLow, poses.flagReachHigh, poses.flagHidden])
        // Gripping hands hold from the moment they grip.
        for time in samples(flag) {
            guard let (a, b) = segment(flag, at: time) else { continue }
            let s = FigureSkeleton(flag.joints(at: time))
            for limb in FigureLimb.allCases where b.limbs[limb] == .held {
                let start = FigureSkeleton(a.joints).end(of: limb)
                guard distance(start, FigureSkeleton(b.joints).end(of: limb)) < 0.6 else { continue }
                #expect(distance(s.end(of: limb), start) < 0.6, "\(limb) at \(time)")
            }
        }
        neverSquashed(flag)
        // Staying out: a smooth way back to the peek, still never squashed.
        let stays = FigureTimeline(action: .flag, entrance: .climb, reduceMotion: false, edge: .trailing)
        #expect(stays.keyframes[0].joints == poses.flagHidden)
        #expect(stays.final == poses.peek)
        neverSquashed(stays)
    }

    @Test("A tap mid-flag leaves around the edge, hidden at the jump; the peek still ducks")
    func flagRelocation() throws {
        let timeline = FigureTimeline(
            action: .wave, entrance: .spring, reduceMotion: false, edge: .top,
            relocating: true, from: .trailing, pose: FigureEdgePoses.flagB
        )
        let jump = try #require(timeline.relocatesAt)
        #expect(timeline.joints(at: 0) == FigureEdgePoses.flagB)
        #expect(timeline.keyframes.contains { abs($0.time - jump) < 1e-9 && $0.joints == FigureEdgePoses.flagHidden })
        #expect(FigureEdgePoses.route(leaving: FigureEdgePoses.flagSwing) != nil)
        #expect(FigureEdgePoses.route(leaving: FigureEdgePoses.peekOut) == nil)
    }
}

