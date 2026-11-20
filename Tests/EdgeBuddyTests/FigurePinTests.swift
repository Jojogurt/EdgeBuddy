import CoreGraphics
import Testing
@testable import EdgeBuddy

@Suite("Pinned figure — fixed anchor, edge and hold frame")
struct FigurePinTests {
    private let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)
    private let metrics = PeekingFigureMetrics.standard
    private let style = FigureStyle.standard

    /// Three cards well inside the viewport, away from its sides.
    private var anchors: [FigureAnchorFrame] {
        [
            FigureAnchorFrame(id: AnyHashable("hero"), edges: .all, rect: CGRect(x: 40, y: 120, width: 320, height: 200)),
            FigureAnchorFrame(id: AnyHashable("stats"), edges: .top, rect: CGRect(x: 40, y: 400, width: 320, height: 160)),
            FigureAnchorFrame(id: AnyHashable("week"), edges: [.top, .bottom], rect: CGRect(x: 40, y: 620, width: 320, height: 100)),
        ]
    }

    private func resolve(_ pin: FigurePin, anchors: [FigureAnchorFrame]? = nil) -> FigurePinnedPlay? {
        FigurePinnedPlay.resolve(pin, anchors: anchors ?? self.anchors, viewport: viewport, metrics: metrics, style: style)
    }

    @Test("The pin chooses its anchor and edge, every time", arguments: [
        ("hero", FigureEdges.top, FigureEdge.top),
        ("hero", .bottom, .bottom),
        ("hero", .leading, .leading),
        ("hero", .trailing, .trailing),
        ("stats", .top, .top),
        ("week", .bottom, .bottom),
    ])
    func chosenAnchorAndEdge(anchor: String, edges: FigureEdges, expected: FigureEdge) throws {
        // A side only plays the flag (a rest pinned there goes to the top).
        let pin = FigurePin(anchor: anchor, edge: edges, pose: expected.isSide ? .flag : .rest)
        let first = try #require(resolve(pin))
        #expect(first.anchor == AnyHashable(anchor))
        #expect(first.edge == expected)
        // No random picks: the same pin resolves the same way every time.
        for _ in 0..<50 {
            #expect(resolve(pin) == first)
        }
    }

    @Test("A pin ignores the edges its anchor allows")
    func pinOverridesAnchorEdges() throws {
        // "stats" only allows the top; the pin still goes to its trailing side.
        let play = try #require(resolve(FigurePin(anchor: "stats", edge: .trailing, pose: .flag)))
        #expect(play.edge == .trailing)
        #expect(play.action == FigureAction.flag.name)
    }

    @Test("A rest or a top pose pinned at a side plays on the top of that anchor", arguments: [
        (FigurePose.rest, FigureEdges.trailing), (.rest, .leading), (.wave, .trailing), (.handstand, .leading),
    ])
    func sidePinGoesToTheTop(pose: FigurePose, edge: FigureEdges) throws {
        #expect(!pose.edges.contains(.leading) && !pose.edges.contains(.trailing))
        let play = try #require(resolve(FigurePin(anchor: "hero", edge: edge, pose: pose)))
        #expect(play.anchor == AnyHashable("hero"))
        #expect(play.edge == .top)
        #expect(play.action == pose.name)
        // The same as pinning it on the top.
        let top = try #require(resolve(FigurePin(anchor: "hero", edge: .top, pose: pose)))
        #expect(play.action == top.action && play.holdTime == top.holdTime && play.spot == top.spot)
        // Even on an anchor that only allows its sides (a pin ignores them).
        let sides = [FigureAnchorFrame(id: AnyHashable("hero"), edges: [.leading, .trailing], rect: anchors[0].rect)]
        #expect(try #require(resolve(FigurePin(anchor: "hero", edge: edge, pose: pose), anchors: sides)).edge == .top)
        // The flag stays at the side.
        let flag = FigurePin(anchor: "hero", edge: edge, pose: .flag)
        #expect(try #require(resolve(flag)).edge == flag.figureEdge)
    }

    @Test("A side pin moved to the top falls back when the top doesn't fit")
    func sidePinTopDoesNotFit() throws {
        // The card's top is too close to the viewport's top for the figure; its sides fit.
        let high = [FigureAnchorFrame(id: AnyHashable("hero"), edges: .all, rect: CGRect(x: 40, y: 10, width: 320, height: 200))]
        #expect(resolve(FigurePin(anchor: "hero", edge: .top, pose: .rest), anchors: high) == nil)
        #expect(resolve(FigurePin(anchor: "hero", edge: .trailing, pose: .rest), anchors: high) == nil)
        #expect(resolve(FigurePin(anchor: "hero", edge: .trailing, pose: .wave), anchors: high) == nil)
        #expect(try #require(resolve(FigurePin(anchor: "hero", edge: .trailing, pose: .flag), anchors: high)).edge == .trailing)
    }

    @Test("FigurePose.rest is no side pose: top and bottom only")
    func restEdges() {
        #expect(FigurePose.rest.edges == [.top, .bottom])
        #expect(FigurePose.allCases.filter { $0.edges.contains(.trailing) } == [.flag])
        #expect(FigurePose.allCases.filter { $0.edges.contains(.leading) } == [.flag])
    }

    @Test("Several edges: the first of top, bottom, leading, trailing; none = top")
    func singleEdge() {
        #expect(FigurePin(anchor: 1, edge: [.trailing, .bottom], pose: .rest).figureEdge == .bottom)
        #expect(FigurePin(anchor: 1, edge: [.trailing, .leading], pose: .rest).figureEdge == .leading)
        #expect(FigurePin(anchor: 1, edge: [], pose: .rest).figureEdge == .top)
    }

    @Test("Falls back (nil) when the anchor is missing, off screen or too small")
    func fallsBack() {
        #expect(resolve(FigurePin(anchor: "missing", pose: .wave)) == nil)
        // Off screen: the top edge is below the viewport.
        let below = [FigureAnchorFrame(id: AnyHashable("low"), edges: .all, rect: CGRect(x: 40, y: 900, width: 320, height: 120))]
        #expect(resolve(FigurePin(anchor: "low", pose: .wave), anchors: below) == nil)
        // Too narrow for the figure.
        let narrow = [FigureAnchorFrame(id: AnyHashable("chip"), edges: .all, rect: CGRect(x: 40, y: 300, width: 60, height: 120))]
        #expect(resolve(FigurePin(anchor: "chip", pose: .wave), anchors: narrow) == nil)
        // Too short for a side.
        let short = [FigureAnchorFrame(id: AnyHashable("row"), edges: .all, rect: CGRect(x: 40, y: 300, width: 320, height: 40))]
        #expect(resolve(FigurePin(anchor: "row", edge: .trailing, pose: .flag), anchors: short) == nil)
    }

    @Test("Unbounded stage (a single card) takes any anchor that is wide enough")
    func unbounded() throws {
        let solo = [FigureAnchorFrame(id: AnyHashable(7), edges: .top, rect: CGRect(x: 0, y: -500, width: 300, height: 120))]
        let play = try #require(FigurePinnedPlay.resolve(
            FigurePin(anchor: 7, pose: .handstand), anchors: solo, viewport: nil, metrics: metrics, style: style
        ))
        #expect(play.edge == .top)
        #expect(play.action == FigureAction.handstand.name)
    }

    @Test("The spot is the pin's, clamped to 0…1; default the middle")
    func spot() throws {
        #expect(try #require(resolve(FigurePin(anchor: "hero", pose: .wave))).spot == 0.5)
        #expect(try #require(resolve(FigurePin(anchor: "hero", pose: .wave, spot: 0.9))).spot == 0.9)
        #expect(try #require(resolve(FigurePin(anchor: "hero", pose: .wave, spot: 4))).spot == 1)
        #expect(try #require(resolve(FigurePin(anchor: "hero", pose: .wave, spot: -1))).spot == 0)
    }

    @Test("A pose of another edge rests there; at a side it plays on the anchor's top")
    func poseOfAnotherEdge() throws {
        #expect(try #require(resolve(FigurePin(anchor: "hero", edge: .bottom, pose: .wave))).action == FigureAction.rest.name)
        #expect(try #require(resolve(FigurePin(anchor: "hero", edge: .top, pose: .flag))).action == FigureAction.rest.name)
        // A bottom pose pinned at a side: on the top, where it rests.
        let pullUp = try #require(resolve(FigurePin(anchor: "hero", edge: .leading, pose: .pullUp)))
        #expect(pullUp.edge == .top && pullUp.action == FigureAction.rest.name)
        for pose in FigurePose.allCases {
            for edge in FigureEdge.allCases where pose.edges.contains(edge.member) {
                if pose != .rest { #expect(pose.action(at: edge) != .rest) }
            }
        }
    }

    @Test("Freezes at the pose's hold frame", arguments: [
        (FigurePose.handstand, FigureEdges.top, FigureEdgePoses.handstand),
        (.swing, .bottom, FigureEdgePoses.swingLeft),
        (.pullUp, .bottom, FigureEdgePoses.pullTop),
        (.flag, .trailing, FigureEdgePoses.flagA),
        (.flag, .leading, FigureEdgePoses.flagA),
        (.rest, .top, FigureJoints.rest),
        (.rest, .bottom, FigureEdgePoses.hang),
        // No rest at a side: it stands on the anchor's top.
        (.rest, .trailing, FigureJoints.rest),
        (.rest, .leading, FigureJoints.rest),
    ])
    func holdFrame(pose: FigurePose, edge: FigureEdges, expected: FigureJoints) throws {
        for animated in [true, false] {
            let play = try #require(resolve(FigurePin(anchor: "hero", edge: edge, pose: pose, animated: animated)))
            #expect(play.timeline.joints(at: play.holdTime) == expected)
        }
    }

    @Test("Top poses hold their signature: arm up, jacks open, bent, knee up, arms in a V")
    func topHoldFrames() throws {
        func held(_ pose: FigurePose) throws -> FigureJoints {
            let play = try #require(resolve(FigurePin(anchor: "hero", pose: pose)))
            return try #require(play.timeline.joints(at: play.holdTime))
        }
        #expect(try held(.wave).armR == 148)
        #expect(try held(.jumpingJacks).armL == -150)
        #expect(try held(.sideStretch).lean == -18)
        #expect(try held(.march).legL == -60)
        #expect(try held(.celebrate) == FigureEdgePoses.celebrateVictory)
    }

    @Test("Animated pins come out first; still ones skip the entrance")
    func entrance() throws {
        let animated = try #require(resolve(FigurePin(anchor: "hero", pose: .wave)))
        let still = try #require(resolve(FigurePin(anchor: "hero", pose: .wave, animated: false)))
        #expect(animated.timeline.joints(at: 0) != .rest)
        #expect(still.timeline.joints(at: 0) == .rest)
        #expect(animated.holdTime > still.holdTime)
        // Never ends hidden, never loops.
        #expect(animated.timeline.hiddenPause == nil)
        #expect(still.timeline.hiddenPause == nil)
    }

    @Test("Reduce Motion timelines have no hold frame; pins build without it")
    func reduceMotion() {
        #expect(FigureTimeline(action: .wave, entrance: .climb, reduceMotion: true).holdTime == nil)
        #expect(FigureTimeline(action: .wave, entrance: .climb, reduceMotion: false).holdTime != nil)
    }
}

@Suite("Pinned figure — single card")
struct FigurePinSingleCardTests {
    @Test("singleCard pins the peekingFigure's own anchor only")
    func singleCard() throws {
        let solo = [FigureAnchorFrame(id: AnyHashable(SoloAnchor.id), edges: .top, rect: CGRect(x: 0, y: 0, width: 300, height: 120))]
        let play = try #require(FigurePinnedPlay.resolve(
            .singleCard(pose: .wave), anchors: solo, viewport: nil, metrics: .standard, style: .standard
        ))
        #expect(play.anchor == AnyHashable(SoloAnchor.id))
        #expect(play.action == FigureAction.wave.name)
        #expect(FigurePinnedPlay.resolve(
            FigurePin(anchor: "hero", pose: .wave), anchors: solo, viewport: nil, metrics: .standard, style: .standard
        ) == nil)
    }
}

/// The human rig's pose of a type-erased play.
extension FigurePlay {
    func joints(at time: Double) -> FigureJoints? {
        (base as? FigureTimeline)?.joints(at: time)
    }
}
