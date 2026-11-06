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
        (.walk, 2.95),
        (.run, 3.16),
    ])
    func actionDurations(action: FigureAction, expected: Double) {
        let played = FigureTimeline(action: action, entrance: nil, reduceMotion: false)
        #expect(abs(played.duration - expected) < 1e-9)
        let entered = FigureTimeline(action: action, entrance: .spring, reduceMotion: false)
        #expect(abs(entered.duration - (expected + entrance)) < 1e-9)
    }

    @Test("Every action starts and ends at rest", arguments: [
        FigureAction.rest, .wave, .jumpingJacks, .sideStretch, .march, .walk, .run,
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
        let normal = FigureTimeline(action: .walk, entrance: .climb, reduceMotion: false, relocating: true)
        let fast = FigureTimeline(action: .walk, entrance: .climb, reduceMotion: false, relocating: true, tempo: 2)
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

    @Test("Walk travels during the steps only; march stays in place")
    func walkWindow() throws {
        let walk = FigureTimeline(action: .walk, entrance: .spring, reduceMotion: false)
        let window = try #require(walk.walkWindow)
        #expect(abs(window.lowerBound - (0.66 + 0.25)) < 1e-9)
        #expect(abs(window.upperBound - (walk.duration - 0.3)) < 1e-9)
        #expect(walk.walkProgress(at: 0) == 0)
        #expect(walk.walkProgress(at: walk.duration) == 1)
        #expect(FigureTimeline(action: .march, entrance: .spring, reduceMotion: false).walkWindow == nil)
        #expect(FigureTimeline(action: .walk, entrance: .spring, reduceMotion: true).walkWindow == nil)
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
        #expect(abs(enter.map(\.0).reduce(0, +) - exit.map(\.0).reduce(0, +)) < 1e-9)
        #expect(exit.last?.1 == FigureTimeline.hiddenPose(entrance))
        #expect(Array(exit.dropLast().map(\.1)) == Array(enter.dropLast().map(\.1).reversed()))
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
        (FigureAction.wave, 0.4), (.jumpingJacks, 0.6), (.march, 0.8), (.walk, 0.8),
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
        for action in [FigureAction.rest, .wave, .jumpingJacks, .sideStretch, .march, .walk, .run] {
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
            action: .walk, entrance: .spring, reduceMotion: false, variation: loopVariation(repeats: 2, exit: .spring)
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

    @Test("Hidden edge poses stay entirely behind or outside the card")
    func hiddenEdgePoses() {
        let reach = FigureSkeleton.limbWidth / 2 + 0.5
        // Bottom: everything above the card's bottom edge (and the head's radius).
        for point in points(FigureEdgePoses.hangHidden) {
            #expect(point.y + FigureSkeleton.headRadius < FigureEdgePoses.bottomEdgeY)
        }
        // Side: everything right of the card's side edge.
        for point in points(FigureEdgePoses.sideHidden) {
            #expect(point.x - max(reach, FigureSkeleton.headRadius) > FigureEdgePoses.sideEdgeX)
        }
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

    @Test("Flag holds the side edge with both hands, peek with one, head on the card")
    func sideGrips() {
        for pose in [FigureEdgePoses.flagA, FigureEdgePoses.flagB] {
            let s = FigureSkeleton(pose)
            #expect(abs(s.armL[2].x - (FigureEdgePoses.sideEdgeX - 2.5)) < 0.6)
            #expect(abs(s.armR[2].x - (FigureEdgePoses.sideEdgeX - 2.5)) < 0.6)
            #expect(s.head.x + FigureSkeleton.headRadius < FigureEdgePoses.sideEdgeX)
            // Body flat: torso horizontal.
            #expect(abs(s.hip.y - s.torsoTop.y) < 0.5)
        }
        let peek = FigureSkeleton(FigureEdgePoses.peek)
        #expect(distance(peek.armL[2], CGPoint(x: FigureEdgePoses.sideEdgeX - 2.5, y: 64)) < 0.6)
        #expect(peek.head.x + FigureSkeleton.headRadius < FigureEdgePoses.sideEdgeX)
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

    private let sizes = FigureSizes(figureHeight: 56, minWidth: 108, hangHeight: 49, sideMinHeight: 82)

    @Test("Bottom and side eligibility: hang above the tab bar, side tall enough on screen")
    func edgeEligibility() {
        func ok(_ rect: CGRect, _ edge: FigureEdge) -> Bool {
            FigureAnchorPicker.isEligible(rect: rect, edge: edge, viewport: viewport, sizes: sizes)
        }
        let card = CGRect(x: 16, y: 300, width: 368, height: 120)
        for edge in FigureEdge.allCases { #expect(ok(card, edge)) }
        // Bottom: the hang would reach under the tab bar.
        #expect(!ok(CGRect(x: 16, y: 560, width: 368, height: 100), .bottom))
        #expect(ok(CGRect(x: 16, y: 500, width: 368, height: 100), .bottom))
        // Bottom edge scrolled above the top.
        #expect(!ok(CGRect(x: 16, y: -100, width: 368, height: 210), .bottom))
        // Side: too short a card, or too little of it on screen.
        #expect(!ok(CGRect(x: 16, y: 300, width: 368, height: 60), .trailing))
        #expect(!ok(CGRect(x: 16, y: 640, width: 368, height: 300), .leading))
        #expect(ok(CGRect(x: 16, y: 600, width: 368, height: 300), .leading))
    }

    @Test("Edge weights: top 60%, bottom 20%, each side 10%; renormalized; top only when asked")
    func edgeWeights() {
        var generator = SystemRandomNumberGenerator()
        let card = (id: "a", rect: CGRect(x: 16, y: 300, width: 368, height: 120), edges: FigureEdges.all)
        var counts: [FigureEdge: Int] = [:]
        let draws = 6000
        for _ in 0..<draws {
            let pick = FigureAnchorPicker.nextPlacement(
                current: nil, candidates: [card], viewport: viewport, sizes: sizes, using: &generator
            )
            counts[pick!.edge, default: 0] += 1
        }
        func share(_ edge: FigureEdge) -> Double { Double(counts[edge, default: 0]) / Double(draws) }
        #expect(abs(share(.top) - 0.6) < 0.04)
        #expect(abs(share(.bottom) - 0.2) < 0.04)
        #expect(abs(share(.leading) - 0.1) < 0.03)
        #expect(abs(share(.trailing) - 0.1) < 0.03)

        // Without the top: bottom 1/2, sides 1/4 each.
        let noTop = (id: "a", rect: card.rect, edges: FigureEdges([.bottom, .leading, .trailing]))
        var bottoms = 0
        for _ in 0..<draws {
            let pick = FigureAnchorPicker.nextPlacement(
                current: nil, candidates: [noTop], viewport: viewport, sizes: sizes, using: &generator
            )
            if pick?.edge == .bottom { bottoms += 1 }
        }
        #expect(abs(Double(bottoms) / Double(draws) - 0.5) < 0.04)

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
}
