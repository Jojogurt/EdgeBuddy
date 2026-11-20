import CoreGraphics
@testable import EdgeBuddy
import Testing

/// The celebration: a winner on the podium — a crouch, hops with both arms
/// up in a V, then standing tall in the V (its hold frame).
@Suite("Celebrate — arms up in a V, hops on the spot")
struct CelebrateTests {
    private let edge = Double(FigureSkeleton.edgeY)
    private let cap = Double(FigureSkeleton.limbWidth) / 2

    private func feetBottom(_ joints: FigureJoints) -> Double {
        let s = FigureSkeleton(joints)
        return Double(max(s.end(of: .legL).y, s.end(of: .legR).y)) + cap
    }

    private func handsTop(_ joints: FigureJoints) -> Double {
        let s = FigureSkeleton(joints)
        return Double(min(s.end(of: .armL).y, s.end(of: .armR).y))
    }

    @Test("Played on the top only, and pinnable there")
    func repertoire() {
        #expect(FigureRepertoire.top.contains(.celebrate))
        #expect(!FigureRepertoire.bottom.contains(.celebrate))
        #expect(!FigureRepertoire.side.contains(.celebrate))
        #expect(FigurePose.celebrate.edges == .top)
        #expect(FigurePose.celebrate.action(at: .top) == .celebrate)
        #expect(FigurePose.celebrate.action(at: .bottom) == .rest)
        #expect(FigureAction(name: "celebrate") == .celebrate)
    }

    @Test("Standing poses keep the feet on the edge like the rest; the hop leaves it")
    func feet() {
        let poses = FigureEdgePoses.self
        let ground = feetBottom(.rest)
        #expect(abs(ground - edge) < 0.3)
        for pose in [poses.celebrateCrouch, poses.celebrateVictory, poses.celebrateLand] {
            #expect(abs(feetBottom(pose) - ground) < 0.05)
        }
        #expect(feetBottom(poses.celebrateAir) < edge - 10)
    }

    @Test("Hold frame: both hands high above the head, standing")
    func victory() throws {
        let timeline = FigureTimeline(action: .celebrate, entrance: nil, reduceMotion: false)
        let hold = try #require(timeline.holdTime)
        let pose = timeline.joints(at: hold)
        #expect(pose == FigureEdgePoses.celebrateVictory)
        let s = FigureSkeleton(pose)
        #expect(handsTop(pose) < Double(s.head.y))
        // A V: the hands spread wider than the shoulders.
        #expect(s.end(of: .armL).x < s.armL[0].x && s.end(of: .armR).x > s.armR[0].x)
    }

    @Test("Hops once per repeat; between hops the feet never sink below the edge", arguments: [2, 3, 4])
    func hops(repeats: Int) {
        let timeline = FigureTimeline(
            action: .celebrate, entrance: nil, reduceMotion: false, variation: FigureVariation(repeats: repeats)
        )
        var airborne = false, hops = 0
        for time in stride(from: 0, through: timeline.duration, by: 1.0 / 120) {
            let bottom = feetBottom(timeline.joints(at: time))
            #expect(bottom <= edge + 0.3, "feet below the edge at \(time)")
            if !airborne, bottom < edge - 5 { hops += 1 }
            airborne = bottom < edge - 5
        }
        #expect(hops == repeats)
        #expect(timeline.walkWindow == nil && timeline.walkDistance == nil)
    }
}
