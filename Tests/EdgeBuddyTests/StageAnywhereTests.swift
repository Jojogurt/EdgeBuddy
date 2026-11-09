import CoreGraphics
import Testing
@testable import EdgeBuddy

@Suite("Stage anywhere — per-scroll-view regions")
struct StageAnywhereTests {
    private let stage = CGRect(x: 0, y: 0, width: 390, height: 844)
    private var metrics: PeekingFigureMetrics { .standard }

    @Test("No region: the whole stage")
    func noRegion() {
        #expect(FigureViewport.resolve(stage: stage, region: nil, origin: .zero) == stage)
    }

    @Test("A region between bars narrows the stage; global space is shifted by the stage's origin")
    func betweenBars() {
        let region = CGRect(x: 0, y: 153 + 47, width: 390, height: 608)
        let visible = FigureViewport.resolve(stage: stage, region: region, origin: CGPoint(x: 0, y: 47))
        #expect(visible == CGRect(x: 0, y: 153, width: 390, height: 608))
    }

    @Test("A region reaching past the stage is cut; one outside is empty")
    func clipped() {
        let wide = CGRect(x: -20, y: 100, width: 500, height: 2000)
        #expect(FigureViewport.resolve(stage: stage, region: wide, origin: .zero) == CGRect(x: 0, y: 100, width: 390, height: 744))
        let outside = FigureViewport.resolve(stage: stage, region: CGRect(x: 0, y: 2000, width: 100, height: 100), origin: .zero)
        #expect(outside.isEmpty)
    }

    @Test("A card under a translucent bar is not eligible in its own scroll view's viewport")
    func underBar() {
        let card = CGRect(x: 16, y: 120, width: 358, height: 120)
        let underBar = CGRect(x: 0, y: 153, width: 390, height: 608)
        // Eligible against the whole stage, not against the area between the bars
        // (the head would reach under the bar).
        #expect(FigureAnchorPicker.isEligible(rect: card, edge: .top, viewport: stage, sizes: metrics.sizes))
        #expect(!FigureAnchorPicker.isEligible(rect: card, edge: .top, viewport: underBar, sizes: metrics.sizes))
    }

    @Test("The picker uses each anchor's own viewport")
    func perAnchorViewport() {
        var generator = SystemRandomNumberGenerator()
        let a = (id: "a", rect: CGRect(x: 16, y: 300, width: 358, height: 120), edges: FigureEdges.top)
        let b = (id: "b", rect: CGRect(x: 16, y: 500, width: 358, height: 120), edges: FigureEdges.top)
        // `a` sits in a scroll view that ends above it: never picked.
        let viewports: [String: CGRect] = ["a": CGRect(x: 0, y: 0, width: 390, height: 200), "b": stage]
        for _ in 0..<50 {
            let pick = FigureAnchorPicker.nextPlacement(
                current: nil, candidates: [a, b], viewport: stage, viewportFor: { viewports[$0] },
                sizes: metrics.sizes, allowed: .top, using: &generator
            )
            #expect(pick?.id == "b")
        }
    }

    @Test("A pin resolves against its anchor's viewport")
    func pinUsesAnchorViewport() {
        let card = CGRect(x: 16, y: 120, width: 358, height: 120)
        let free = FigureAnchorFrame(id: AnyHashable("c"), edges: .all, rect: card)
        let bounded = FigureAnchorFrame(
            id: AnyHashable("c"), edges: .all, rect: card, viewport: CGRect(x: 0, y: 153, width: 390, height: 608)
        )
        let pin = FigurePin(anchor: "c", edge: .top, pose: .wave)
        #expect(FigurePinnedPlay.resolve(pin, anchors: [free], viewport: stage, metrics: metrics, style: .standard) != nil)
        #expect(FigurePinnedPlay.resolve(pin, anchors: [bounded], viewport: stage, metrics: metrics, style: .standard) == nil)
    }

    @Test("Not in a scroll view: no region; one scroll view alone is used as it is")
    func regionSingleScrollView() {
        let origin = CGPoint(x: 16, y: 300)
        #expect(FigureViewport.region(vertical: nil, horizontal: nil, origin: origin) == nil)
        let local = CGRect(x: -16, y: -200, width: 390, height: 600)
        let global = CGRect(x: 0, y: 100, width: 390, height: 600)
        #expect(FigureViewport.region(vertical: local, horizontal: nil, origin: origin) == global)
        #expect(FigureViewport.region(vertical: nil, horizontal: local, origin: origin) == global)
    }

    /// The screen's vertical scroll view between its bars (global space), and a
    /// horizontal pager in it, about as tall as its card, scrolled up by `offset`.
    private func nestedPager(offset: CGFloat) -> (vertical: CGRect, horizontal: CGRect, origin: CGPoint) {
        let screen = CGRect(x: 0, y: 153, width: 390, height: 608)
        let pager = CGRect(x: 0, y: 400 - offset, width: 390, height: 180)
        // The card on the pager's current page, 16 pt in, 10 pt down.
        let card = CGPoint(x: 16, y: pager.minY + 10)
        let local = { (rect: CGRect) in rect.offsetBy(dx: -card.x, dy: -card.y) }
        return (local(screen), local(pager), card)
    }

    @Test("A card in a pager in a vertical scroll view: Y from the vertical one, X from the pager")
    func regionNestedPager() {
        let nested = nestedPager(offset: 0)
        let region = FigureViewport.region(vertical: nested.vertical, horizontal: nested.horizontal, origin: nested.origin)
        // Not the pager's frame (y 400, height 180) — the figure has room above and below the card.
        #expect(region == CGRect(x: 0, y: 153, width: 390, height: 608))
    }

    @Test("The pager's X narrows the region (cards of other pages are cut off)")
    func regionPagerNarrowsX() {
        let origin = CGPoint(x: 40, y: 300)
        let vertical = CGRect(x: -40, y: -147, width: 390, height: 608)   // global x 0…390
        let horizontal = CGRect(x: -20, y: -10, width: 300, height: 180)  // global x 20…320
        let region = FigureViewport.region(vertical: vertical, horizontal: horizontal, origin: origin)
        #expect(region == CGRect(x: 20, y: 153, width: 300, height: 608))
    }

    /// A 390 pt screen with a pager whose `.contentMargins` are 16 pt: its
    /// bounds (as SwiftUI reports them) end at the card, x 16…374.
    private func marginPager(offset: CGFloat) -> (vertical: CGRect, horizontal: CGRect, origin: CGPoint) {
        let card = CGPoint(x: 16, y: 400 - offset)
        let screen = CGRect(x: 0, y: 153, width: 390, height: 608)
        let pagerBounds = CGRect(x: 16, y: card.y, width: 358, height: 296)
        let local = { (rect: CGRect) in rect.offsetBy(dx: -card.x, dy: -card.y) }
        return (local(screen), local(pagerBounds), card)
    }

    @Test("Regression 0.3.1: a pager with content margins leaves its margins to a side figure")
    func regionPagerBleedsIntoMargins() {
        let pager = marginPager(offset: 0)
        let tight = FigureViewport.region(vertical: pager.vertical, horizontal: pager.horizontal, origin: pager.origin)
        #expect(tight?.minX == 16 && tight?.maxX == 374)
        let region = FigureViewport.region(
            vertical: pager.vertical, horizontal: pager.horizontal, origin: pager.origin, width: 358, pagerBleed: 10
        )
        #expect(region == CGRect(x: 6, y: 153, width: 378, height: 608))
    }

    @Test("The pager bleed never reaches past the vertical scroll view (the screen)")
    func regionPagerBleedCappedByScreen() {
        let pager = marginPager(offset: 0)
        let region = FigureViewport.region(
            vertical: pager.vertical, horizontal: pager.horizontal, origin: pager.origin, width: 358,
            pagerBleed: PeekingFigureMetrics().pagerBleed
        )
        #expect(region == CGRect(x: 0, y: 153, width: 390, height: 608))
    }

    @Test("With the pager bleed the region still holds still while the screen scrolls")
    func regionPagerBleedStableWhileScrolling() {
        let bleed = PeekingFigureMetrics().pagerBleed
        let regions = stride(from: CGFloat(0), through: 400, by: 25).map { offset in
            let pager = marginPager(offset: offset)
            return FigureViewport.region(
                vertical: pager.vertical, horizontal: pager.horizontal, origin: pager.origin, width: 358,
                pagerBleed: bleed
            )
        }
        #expect(Set(regions.map { $0.map { [$0.minX, $0.minY, $0.width, $0.height] } }).count == 1)
    }

    @Test("Regression: a viewport change never squashes a climb into one spot (climbing in place)")
    func reclampKeepsTheClimb() {
        // Climbing from 0.85 up to 0.0, the side mostly off screen (pull to
        // refresh): the range is a point — leave the climb alone.
        #expect(FigurePlacement.reclamped(spot: 0.85, walkTarget: 0, into: 0...0) == nil)
        // A range that would squash both ends onto 0.2 — left alone too.
        #expect(FigurePlacement.reclamped(spot: 0.85, walkTarget: 0.9, into: 0...0.2) == nil)
        // A real resize still clamps a climb that keeps some travel.
        let moved = FigurePlacement.reclamped(spot: 0.85, walkTarget: 0, into: 0.1...0.6)
        #expect(moved?.spot == 0.6 && moved?.walkTarget == 0.1)
        // Standing still: clamped as before.
        let still = FigurePlacement.reclamped(spot: 0.9, walkTarget: 0.9, into: 0...0.5)
        #expect(still?.spot == 0.5 && still?.walkTarget == 0.5)
    }

    @Test("The measured parts hold still while the screen scrolls (no state update per frame)")
    func partsStableWhileScrolling() {
        let parts = stride(from: CGFloat(0), through: 400, by: 25).map { offset in
            let pager = marginPager(offset: offset)
            return FigureViewport.parts(
                vertical: pager.vertical, horizontal: pager.horizontal, origin: pager.origin, width: 358
            )
        }
        #expect(Set(parts.map { "\(String(describing: $0))" }).count == 1)
    }

    @Test("Regression: the next page's card peeking into the margin gets no bleed (the figure stays off it)")
    func regionPagerBleedKeepsOtherPagesOut() {
        // NextLeg's carousel: 16 pt content margins, 12 pt between cards — the
        // next page's card starts at x 386, 4 pt before the screen's edge.
        let origin = CGPoint(x: 386, y: 400)
        let vertical = CGRect(x: -386, y: -247, width: 390, height: 608)
        let horizontal = CGRect(x: -370, y: 0, width: 358, height: 296)
        let bleed = PeekingFigureMetrics().pagerBleed
        let parts = FigureViewport.parts(vertical: vertical, horizontal: horizontal, origin: origin, width: 358)
        #expect(parts?.isOnPage == false)
        let region = FigureViewport.region(parts, pagerBleed: bleed)
        #expect(region == CGRect(x: 16, y: 153, width: 358, height: 608))
        // Its leading side (x 386) is not in it, so the figure never comes out there.
        let card = CGRect(x: 386, y: 400, width: 358, height: 296)
        let sizes = PeekingFigureMetrics().sizes
        #expect(!FigureAnchorPicker.isEligible(rect: card, edge: .leading, viewport: region, sizes: sizes))
        // The card of the page shown keeps the bleed.
        let shown = marginPager(offset: 0)
        let onPage = FigureViewport.parts(
            vertical: shown.vertical, horizontal: shown.horizontal, origin: shown.origin, width: 358
        )
        #expect(onPage?.isOnPage == true)
        #expect(FigureViewport.region(onPage, pagerBleed: bleed)?.minX == 0)
    }

    @Test("Regression 0.3.0: the region does not move while the screen scrolls vertically")
    func regionStableWhileScrolling() {
        let regions = stride(from: CGFloat(0), through: 400, by: 25).map { offset in
            let nested = nestedPager(offset: offset)
            return FigureViewport.region(vertical: nested.vertical, horizontal: nested.horizontal, origin: nested.origin)
        }
        #expect(Set(regions.map { $0.map { [$0.minX, $0.minY, $0.width, $0.height] } }).count == 1)
        // The anchor's viewport in a stage under the navigation bar stays put too.
        let origin = CGPoint(x: 0, y: 47)
        let viewports = regions.map { FigureViewport.resolve(stage: stage, region: $0, origin: origin) }
        #expect(viewports.allSatisfy { $0 == CGRect(x: 0, y: 106, width: 390, height: 608) })
    }

    @Test("Floating-point noise in the measure does not change the region (no per-frame updates)")
    func regionIgnoresNoise() {
        // Seen on iOS while scrolling: the top flips between 153.0 and 152.99999999999997.
        let origin = CGPoint(x: 64, y: 410.33333333333337)
        let exact = FigureViewport.region(
            vertical: CGRect(x: -64, y: 153 - origin.y, width: 390, height: 608), horizontal: nil, origin: origin
        )
        let noisy = FigureViewport.region(
            vertical: CGRect(x: -64, y: 152.99999999999997 - origin.y, width: 390, height: 608.0000000000001),
            horizontal: nil, origin: origin
        )
        #expect(exact == noisy)
        #expect(exact == CGRect(x: 0, y: 153, width: 390, height: 608))
    }

    @Test("Scroll tracker counts several scroll views; never goes negative")
    func tracker() {
        var tracker = FigureScrollTracker()
        tracker.phaseChanged(from: false, to: false)
        #expect(!tracker.isScrolling)
        tracker.phaseChanged(from: false, to: true)   // list A starts
        tracker.phaseChanged(from: false, to: true)   // list B starts
        tracker.phaseChanged(from: true, to: false)   // A stops
        #expect(tracker.isScrolling)
        tracker.phaseChanged(from: true, to: false)   // B stops
        #expect(!tracker.isScrolling)
        tracker.phaseChanged(from: true, to: false)   // stray event
        #expect(tracker.count == 0)
    }
}
