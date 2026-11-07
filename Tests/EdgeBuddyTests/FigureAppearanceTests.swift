import Testing
@testable import EdgeBuddy

@Suite struct FigureAppearanceTests {
    @Test func scalesAreClampedOnInitAndMutation() {
        var appearance = FigureAppearance(headScale: 5, limbScale: 0.1, torsoScale: .nan)
        #expect(appearance.headScale == 1.5)
        #expect(appearance.limbScale == 0.6)
        #expect(appearance.torsoScale == 1)
        appearance.headScale = -3
        #expect(appearance.headScale == 0.6)
    }

    @Test func standardIsTheDefaultLook() {
        let standard = FigureAppearance.standard
        #expect(standard.headScale == 1 && standard.limbScale == 1 && standard.torsoScale == 1)
        #expect(standard.headColor == nil && standard.armColor == nil)
        #expect(!standard.mirrorsHead)
    }
}

@Suite struct FigureCharacterTests {
    @Test func pointsCarryTheSkeletonAndAngles() {
        var joints = FigureJoints.rest
        joints.lean = 12
        joints.tilt = -5
        joints.facing = -1
        let skeleton = FigureSkeleton(joints)
        let points = FigureSkeletonPoints(skeleton, joints: joints)
        #expect(points.hip == skeleton.hip && points.head == skeleton.head)
        #expect(points.legR == skeleton.legR && points.armL == skeleton.armL)
        #expect(points.lean == 12 && points.tilt == -5 && points.facing == -1)
        #expect(points.farLimbOpacity == skeleton.farLimbOpacity)
    }

    @Test func characterIsStoredOnTheAppearance() {
        #expect(FigureAppearance.standard.character == nil)
        #expect(FigureAppearance(character: Stickman()).character is Stickman)
    }
}
