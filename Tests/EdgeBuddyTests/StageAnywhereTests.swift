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
