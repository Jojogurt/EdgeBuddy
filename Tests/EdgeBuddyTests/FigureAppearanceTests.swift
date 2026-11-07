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
