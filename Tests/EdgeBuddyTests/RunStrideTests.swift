import CoreGraphics
import Foundation
import Testing
@testable import EdgeBuddy

@Suite("Run along the edge — planted feet, steady pace")
struct RunStrideTests {
    private let ground = FigureEdgePoses.groundY
    private let stride = FigureJoints.edgeRunStride

    @Test("The stride is periodic: phase 0 and phase 1 are the same pose")
    func periodic() {
        #expect(FigureJoints.edgeRun(phase: 0) == FigureJoints.edgeRun(phase: 1))
        let a = FigureJoints.edgeRun(phase: 0.3), b = FigureJoints.edgeRun(phase: 2.3)
        for (x, y) in [(a.legL, b.legL), (a.legR, b.legR), (a.kneeL, b.kneeL), (a.kneeR, b.kneeR), (a.armR, b.armR), (a.y, b.y)] {
            #expect(abs(x - y) < 1e-9)
        }
    }

    @Test("The lowest foot never goes below the edge")
    func neverSinks() {
        for i in 0...400 {
            let skeleton = FigureSkeleton(FigureJoints.edgeRun(phase: Double(i) / 200))
            let lowest = max(skeleton.legL[2].y, skeleton.legR[2].y)
            #expect(lowest <= ground + 0.05)
        }
    }

    @Test("The stride is 2 * half stride per stance share")
    func strideLength() {
        #expect(abs(stride - 2 * 16 / 0.36) < 1e-9)
    }

    @Test("Foot lock: a planted foot stays put in the world")
    func footLock() throws {
        let run = FigureTimeline(action: .run, entrance: nil, reduceMotion: false)
        let window = try #require(run.walkWindow)
        let distance = try #require(run.walkDistance)
        let beta = FigureJoints.edgeRunStance
        var worstDrift = 0.0
        var worstHeight = 0.0
        var stances = 0
        // Each foot is planted for the first `beta` of its half-cycle turn
        // (the far leg half a cycle later); sampled at 240 Hz off the timeline.
        for (leg, offset) in [(FigureLimb.legR, 0.0), (.legL, 0.5)] {
            var current: (turn: Int, low: Double, high: Double)?
            func close() {
                if let current {
                    worstDrift = max(worstDrift, current.high - current.low)
                    stances += 1
                }
                current = nil
            }
            var time = window.lowerBound
            while time <= window.upperBound {
                let phase = (time - window.lowerBound) / FigureJoints.runCycle + 1 - offset
                let turn = Int(phase.rounded(.down))
                if phase - Double(turn) < beta {
                    let foot = FigureSkeleton(run.joints(at: time)).end(of: leg)
                    let world = Double(foot.x) + (run.walkProgress(at: time) ?? 0) * distance
                    worstHeight = max(worstHeight, abs(Double(foot.y) - ground))
                    if let held = current, held.turn == turn {
                        current = (turn, min(held.low, world), max(held.high, world))
                    } else {
                        close()
                        current = (turn, world, world)
                    }
                } else {
                    close()
                }
                time += 1.0 / 240
            }
            close()
        }
        print("RunStrideTests: max planted-foot drift \(worstDrift) over \(stances) stances, off the edge by up to \(worstHeight)")
        #expect(stances >= 7)
        #expect(worstDrift < 0.5)
        #expect(worstHeight < 0.2)
    }

    @Test("The walk carries the figure exactly repeats * stride, at a steady pace")
    func walkDistance() throws {
        for repeats in 1...5 {
            let run = FigureTimeline(
                action: .run, entrance: nil, reduceMotion: false, variation: FigureVariation(repeats: repeats)
            )
            let distance = try #require(run.walkDistance)
            #expect(abs(distance - Double(repeats) * stride) < 1e-9)
            #expect(abs(distance - (try #require(FigureTimeline.travel(.run, repeats: repeats)))) < 1e-9)
            let window = try #require(run.walkWindow)
            #expect(abs((run.walkProgress(at: window.lowerBound) ?? -1)) < 1e-9)
            #expect(abs((run.walkProgress(at: window.upperBound) ?? -1) - 1) < 1e-9)
            // Constant ground speed: half-way in time is half-way in distance.
            let middle = (window.lowerBound + window.upperBound) / 2
            #expect(abs((run.walkProgress(at: middle) ?? -1) - 0.5) < 1e-9)
        }
    }

    @Test("Turning in and back out takes no travel")
    func noTravelOutsideTheStrides() throws {
        let run = FigureTimeline(action: .run, entrance: nil, reduceMotion: false)
        let window = try #require(run.walkWindow)
        #expect(run.walkProgress(at: window.lowerBound - 0.1) == 0)
        #expect(run.walkProgress(at: window.upperBound + 0.1) == 1)
    }

    @Test("The run is offered only where a whole cycle fits")
    func needsOneCycle() {
        #expect(abs((FigureTimeline.minimumTravel(.run) ?? 0) - stride) < 1e-9)
        #expect(!FigureRepertoire.actions(for: .top, room: stride - 1).contains(.run))
        #expect(FigureRepertoire.actions(for: .top, room: stride).contains(.run))
    }

    @Test("Cycles that fit a 300 pt card, from its middle and from its end")
    func cyclesOnACard() {
        let metrics = PeekingFigureMetrics.standard
        let card = CGRect(x: 0, y: 0, width: 300, height: 200)
        let fromMiddle = metrics.travelRoom(at: .top, on: card, viewport: nil, from: 0.5)
        let fromEnd = metrics.travelRoom(at: .top, on: card, viewport: nil, from: 0)
        let middleCycles = Int((fromMiddle + 1e-9) / stride)
        let endCycles = Int((fromEnd + 1e-9) / stride)
        print("RunStrideTests: 300 pt card: \(middleCycles) cycles from the middle, \(endCycles) from the end")
        #expect(endCycles >= 1)
        #expect(FigureRepertoire.actions(for: .top, room: fromMiddle).contains(.run) == (middleCycles >= 1))
    }

    @Test("The loader's run in place is unchanged")
    func loaderRunUnchanged() {
        let start = FigureJoints.run(phase: 0)
        #expect(start.profile == 1 && start.lean == 9)
        #expect(abs(start.y - -2.5) < 1e-9)
        #expect(abs(start.kneeR - -41) < 1e-9 && abs(start.kneeL - -41) < 1e-9)
        let quarter = FigureJoints.run(phase: 0.25)
        #expect(abs(quarter.legR - 38) < 1e-9 && abs(quarter.legL - -38) < 1e-9)
        #expect(abs(quarter.armR - -42) < 1e-9 && abs(quarter.armL - 42) < 1e-9)
        #expect(abs(quarter.kneeR - -12) < 1e-9 && abs(quarter.kneeL - -70) < 1e-9)
    }

    @Test("Running left mirrors the stride around the hip")
    func mirrors() {
        let pose = FigureJoints.edgeRun(phase: 0.2)
        let right = FigureSkeleton(pose)
        let left = FigureSkeleton(pose.with { $0.facing = -1 })
        for limb in [FigureLimb.legL, .legR] {
            #expect(abs(Double(left.end(of: limb).x) - (100 - Double(right.end(of: limb).x))) < 1e-9)
            #expect(abs(Double(left.end(of: limb).y) - Double(right.end(of: limb).y)) < 1e-9)
        }
    }
}
