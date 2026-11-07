import SwiftUI
import Testing
@testable import EdgeBuddy

@Suite struct HumanFigureLookTests {
    @Test func scalesAreClampedOnInitAndMutation() {
        var figure = HumanFigure(headScale: 5, limbScale: 0.1, torsoScale: .nan)
        #expect(figure.headScale == 1.5)
        #expect(figure.limbScale == 0.6)
        #expect(figure.torsoScale == 1)
        figure.headScale = -3
        #expect(figure.headScale == 0.6)
    }

    @Test func defaultIsThePlainLook() {
        let figure = HumanFigure()
        #expect(figure.headScale == 1 && figure.limbScale == 1 && figure.torsoScale == 1)
        #expect(figure.headColor == nil && figure.armColor == nil)
        #expect(!figure.mirrorsHead)
        if case .circle = figure.head {} else { Issue.record("default head is not the circle") }
    }

    @Test("The look never changes motion, layout or taps")
    func lookDoesNotChangeTheRig() throws {
        let plain = AnyFigureCharacter(HumanFigure())
        let bear = AnyFigureCharacter(HumanFigure(head: .text("🐻"), headScale: 1.5, limbScale: 0.6, armColor: .orange))
        #expect(plain.typeID == bear.typeID)
        #expect(plain.geometry == bear.geometry)
        let request = FigurePlayRequest(action: "handstand", entrance: .climb, reduceMotion: false)
        #expect(plain.play(request) == bear.play(request))
        let play = plain.play(request)
        for time in stride(from: 0.0, through: play.duration, by: 0.1) {
            let a = try #require(plain.frame(play, at: time, edge: .top, heading: 0))
            let b = try #require(bear.frame(play, at: time, edge: .top, heading: 0))
            #expect(a.isOut == b.isOut && a.isMirrored == b.isMirrored)
        }
    }
}

@Suite struct HumanPoseTests {
    @Test func pointsCarryTheSkeletonAndAngles() {
        var joints = FigureJoints.rest
        joints.lean = 12
        joints.tilt = -5
        joints.facing = -1
        let skeleton = FigureSkeleton(joints)
        let points = HumanFigure.Pose(joints).points
        #expect(points.hip == skeleton.hip && points.head == skeleton.head)
        #expect(points.legR == skeleton.legR && points.armL == skeleton.armL)
        #expect(points.lean == 12 && points.tilt == -5 && points.facing == -1)
        #expect(points.farLimbOpacity == skeleton.farLimbOpacity)
    }
}
