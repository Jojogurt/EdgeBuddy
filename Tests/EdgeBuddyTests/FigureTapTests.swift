import CoreGraphics
@testable import EdgeBuddy
import Testing

/// A tap always sends the figure behind its card and brings it out again —
/// also while the stage waits (`isWaiting`: a celebration, a tip card that
/// may be scrolled out of view). It never just stands there ignoring taps.
@Suite("Tap — always back behind the card and out again")
struct FigureTapTests {
    @Test("A free figure relocates and plays a new action")
    func free() {
        #expect(FigureTap.response(reduceMotion: false, isWaiting: false, isPinned: false) == .relocate)
    }

    @Test("While the stage waits a tap still ducks and comes out again, resting (no action)")
    func waiting() {
        #expect(FigureTap.response(reduceMotion: false, isWaiting: true, isPinned: false) == .relocateResting)
    }

    @Test("Only a pin or Reduce Motion ignores taps", arguments: [
        (true, false, false), (false, false, true), (true, true, false), (false, true, true),
    ])
    func ignored(reduceMotion: Bool, waiting: Bool, pinned: Bool) {
        #expect(FigureTap.response(reduceMotion: reduceMotion, isWaiting: waiting, isPinned: pinned) == .ignore)
    }

    @Test("The waiting tap's play: from standing on a top, hidden at the jump, out again and standing")
    func waitingPlay() throws {
        let human = HumanRig.standard
        // What `PeekingFigureView.play` asks for on a waiting tap: the rest,
        // relocating, single (no loop variation), from the top's rest.
        let play = human.play(FigurePlayRequest(
            action: FigureActionName.rest, entrance: FigureStyle.standard.entrance, reduceMotion: false,
            edge: .top, relocating: true, previousEdge: .top, previousPose: FigureJoints.rest,
            tempo: FigureStyle.standard.tempo, variation: .standard
        ))
        let jump = try #require(play.relocatesAt)
        #expect(try #require(human.frame(play, at: 0, edge: .top, heading: 0)).isOut)
        #expect(try #require(human.frame(play, at: jump, edge: .top, heading: 0)).isOut == false)
        #expect(try #require(human.frame(play, at: play.duration, edge: .top, heading: 0)).isOut)
        // Single: it stands again, the cycle carries on after the wait.
        #expect(play.hiddenPause == nil)
    }
}
