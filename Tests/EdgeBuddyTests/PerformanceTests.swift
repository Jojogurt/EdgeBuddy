import CoreGraphics
import Foundation
import Testing
@testable import EdgeBuddy

/// Baseline timings of the pure hot paths (recorded in BACKLOG.md). Each test
/// prints its numbers and asserts only a very generous budget, so a slow CI
/// machine doesn't flake but an order-of-magnitude regression fails.
@Suite("Performance — pure hot paths", .serialized)
struct PerformanceTests {
    /// ProMotion frame budget, seconds — relaxed 200× for unoptimized (debug)
    /// builds, which run in parallel with other tests and ~50–100× slower on
    /// the Simulator; the real baseline is taken with `-c release`.
    #if DEBUG
    private static let frame = 200.0 / 120
    #else
    private static let frame = 1.0 / 120
    #endif

    /// Mean seconds per call over `iterations` runs of `body` (after a warm-up).
    private func mean(iterations: Int, _ body: () -> Void) -> Double {
        for _ in 0..<max(1, iterations / 10) { body() }
        let clock = ContinuousClock()
        let elapsed = clock.measure { for _ in 0..<iterations { body() } }
        let parts = elapsed.components
        return (Double(parts.seconds) + Double(parts.attoseconds) / 1e18) / Double(iterations)
    }

    private func report(_ name: String, _ seconds: Double) {
        print("PERF \(name): \(String(format: "%.2f", seconds * 1e6)) µs")
    }

    private static let cases: [(FigureEdge, FigureAction)] = FigureEdge.allCases.flatMap { edge in
        FigureRepertoire.actions(for: edge).map { (edge, $0) }
    }

    @Test("FigureTimeline.joints(at:) over the whole timeline, every action")
    func timelineSampling() {
        var worst = 0.0
        for (edge, action) in Self.cases {
            let timeline = FigureTimeline(action: action, entrance: .climb, reduceMotion: false, edge: edge)
            let steps = 240
            let dt = timeline.duration / Double(steps)
            var sink = 0.0
            let seconds = mean(iterations: 20) {
                for i in 0...steps { sink += timeline.joints(at: Double(i) * dt).y }
            } / Double(steps + 1)
            #expect(sink.isFinite)
            worst = max(worst, seconds)
            report("joints(at:) \(edge)/\(action)", seconds)
        }
        #expect(worst < Self.frame / 10)
    }

    @Test("A frame through the type-erased character: human rig vs a custom character")
    func erasedFrames() throws {
        let characters: [(String, AnyFigureCharacter, String)] = [
            ("human", AnyFigureCharacter(HumanFigure()), "handstand"),
            ("custom", AnyFigureCharacter(BlobFigure()), "bob"),
        ]
        for (name, character, action) in characters {
            let play = character.play(FigurePlayRequest(
                action: action, entrance: .spring, reduceMotion: false,
                variation: FigureVariation(holdBefore: 0.3, repeats: 2, holdAfter: 0.3, exit: .spring, hiddenPause: 1)
            ))
            let steps = 240
            let dt = play.duration / Double(steps)
            var taps = 0
            let seconds = mean(iterations: 20) {
                for i in 0...steps where character.frame(play, at: Double(i) * dt, edge: .top, heading: 0)?.isOut == true {
                    taps += 1
                }
            } / Double(steps + 1)
            #expect(taps > 0)
            report("frame \(name)/\(action)", seconds)
            #expect(seconds < Self.frame / 10)
        }
    }

    @Test("FigureTimeline.init (building a play), every action")
    func timelineBuild() {
        var worst = 0.0
        for (edge, action) in Self.cases {
            let seconds = mean(iterations: 200) {
                _ = FigureTimeline(action: action, entrance: .climb, reduceMotion: false, edge: edge)
            }
            worst = max(worst, seconds)
            report("FigureTimeline.init \(edge)/\(action)", seconds)
        }
        #expect(worst < Self.frame)
    }

    @Test("FigureSkeleton.init in a loop")
    func skeleton() {
        let poses = (0..<64).map { FigureJoints.run(phase: Double($0) / 64) }
        var sink: CGFloat = 0
        let seconds = mean(iterations: 20_000) {
            for pose in poses { sink += FigureSkeleton(pose).hip.x }
        } / Double(poses.count)
        #expect(sink.isFinite)
        report("FigureSkeleton.init", seconds)
        #expect(seconds < Self.frame / 100)
    }

    @Test("IK placing(...)")
    func placing() {
        let pose = FigureJoints.rest
        var sink = 0.0
        let single = mean(iterations: 20_000) {
            sink += pose.placing(.armL, at: CGPoint(x: 30, y: 20)).armL
        }
        let four = mean(iterations: 20_000) {
            sink += pose.placing(
                armL: CGPoint(x: 30, y: 20), armR: CGPoint(x: 70, y: 20),
                legL: CGPoint(x: 40, y: 60), legR: CGPoint(x: 60, y: 60)
            ).armL
        }
        #expect(sink.isFinite)
        report("placing (1 limb)", single)
        report("placing (4 limbs)", four)
        #expect(four < Self.frame / 10)
    }

    @Test("FigureAnchorPicker.nextPlacement at 10 / 100 / 1000 anchors", arguments: [10, 100, 1000])
    func picker(count: Int) {
        let metrics = PeekingFigureMetrics.standard
        let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)
        let candidates = (0..<count).map { i in
            (id: i, rect: CGRect(x: 16, y: 80 + CGFloat(i) * 140, width: 368, height: 120), edges: FigureEdges.all)
        }
        var generator = SystemRandomNumberGenerator()
        var hits = 0
        let seconds = mean(iterations: count >= 1000 ? 50 : 500) {
            if FigureAnchorPicker.nextPlacement(
                current: 0, candidates: candidates, viewport: viewport,
                sizes: metrics.sizes, allowed: .all, using: &generator
            ) != nil { hits += 1 }
        }
        #expect(hits > 0)
        report("nextPlacement \(count) anchors", seconds)
        #expect(seconds < Self.frame * 4)
    }
}
