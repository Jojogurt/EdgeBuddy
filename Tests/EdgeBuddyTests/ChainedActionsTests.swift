import CoreGraphics
@testable import EdgeBuddy
import Testing

@Suite("Chained actions — several actions per appearance")
struct ChainedActionsTests {
    @Test("By default every appearance plays one action")
    func defaultIsOne() {
        var generator = SystemRandomNumberGenerator()
        #expect(FigureStyle.standard.actionsPerCycle == 1...1)
        #expect((0..<200).allSatisfy { _ in FigureStyle.standard.actionCount(using: &generator) == 1 })
    }

    @Test("The count is drawn from the range; counts below 1 count as 1")
    func countInRange() {
        var generator = SystemRandomNumberGenerator()
        let style = FigureStyle(actionsPerCycle: 2...3)
        let counts = Set((0..<300).map { _ in style.actionCount(using: &generator) })
        #expect(counts == [2, 3])
        let low = FigureStyle(actionsPerCycle: -2...0)
        #expect((0..<50).allSatisfy { _ in low.actionCount(using: &generator) == 1 })
        let mixed = FigureStyle(actionsPerCycle: 0...2)
        #expect(Set((0..<300).map { _ in mixed.actionCount(using: &generator) }) == [1, 2])
    }

    @Test("After an action of a run: next, leave or stand")
    func afterAction() {
        let free = { (left: Int) in
            FigureChain.afterAction(left: left, isScrolling: false, canLoop: true, isWaiting: false)
        }
        #expect(free(2) == .next)
        #expect(free(1) == .next)
        #expect(free(0) == .leave)
        // A scroll cuts the run: the action finished, now it leaves.
        #expect(FigureChain.afterAction(left: 2, isScrolling: true, canLoop: true, isWaiting: false) == .leave)
        // A celebration or idle motion off: it stays standing.
        #expect(FigureChain.afterAction(left: 2, isScrolling: false, canLoop: true, isWaiting: true) == .stand)
        #expect(FigureChain.afterAction(left: 2, isScrolling: false, canLoop: false, isWaiting: false) == .stand)
    }

    @Test("Mid-run an action ends standing; the last one leaves and hides")
    func chainedVariation() {
        var generator = SystemRandomNumberGenerator()
        let cycle = FigureVariation.random(repeats: 2...3, exit: .climb, using: &generator)
        let middle = cycle.chained(continues: true)
        #expect(middle.exit == nil && middle.hiddenPause == 0 && middle.holdAfter == 0)
        #expect(middle.holdBefore == cycle.holdBefore && middle.repeats == cycle.repeats)
        #expect(cycle.chained(continues: false) == cycle)
        let leaving = FigureVariation.leaving(exit: .spring, using: &generator)
        #expect(leaving.exit == .spring && leaving.repeats == 1 && leaving.holdBefore == 0)
        #expect(FigureVariation.hiddenPauseRange.contains(leaving.hiddenPause))
    }

    @Test("A run never climbs in place: after a climb to the top the climb is off the list")
    func noSecondClimbAtTheTop() {
        let metrics = PeekingFigureMetrics()
        let card = CGRect(x: 16, y: 200, width: 358, height: 300)
        let viewport = CGRect(x: 0, y: 0, width: 390, height: 700)
        let range = metrics.spotRange(at: .trailing, on: card, viewport: viewport)
        let fromBottom = metrics.travelRoom(at: .trailing, on: card, viewport: viewport, from: range.upperBound)
        #expect(FigureRepertoire.actions(for: .trailing, room: fromBottom).contains(.climb))
        let atTop = metrics.travelRoom(at: .trailing, on: card, viewport: viewport, from: range.lowerBound)
        #expect(!FigureRepertoire.actions(for: .trailing, room: atTop).contains(.climb))
        // By the screen's edge it only climbs — nothing is left at the top, the run ends.
        #expect(FigureRepertoire.actions(for: .trailing, room: atTop, atScreenEdge: true).isEmpty)
    }
}
