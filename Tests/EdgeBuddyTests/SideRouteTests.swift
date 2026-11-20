import CoreGraphics
@testable import EdgeBuddy
import Testing

/// The side's old rest pose (removed): beside the card, the near hand on
/// the edge, leaning out — kept here only to prove no timeline shows it.
private let legacyPeek = FigureJoints.rest.with {
    $0.armL = -60; $0.elbowL = -60; $0.legL = -4; $0.legR = 6
    $0.lean = 6; $0.x = 66; $0.tilt = -8
}.placing(armL: CGPoint(x: FigureEdgePoses.sideGripX, y: 52))

/// `pose` is the old peek (or its nod), give or take a few units.
private func looksLikePeek(_ pose: FigureJoints) -> Bool {
    abs(pose.x - legacyPeek.x) < 8 && abs(pose.y - legacyPeek.y) < 8 && abs(pose.lean - legacyPeek.lean) < 8
        && pose.profile < 0.5 && abs(pose.legL - legacyPeek.legL) < 8 && abs(pose.legR - legacyPeek.legR) < 8
}

/// At a side the figure only shows inside the flag or the climb: every
/// keyframe is behind the card or a pose of a side route, and no frame is
/// (close to) the old peek.
func expectNeverStandsAtSide(
    _ timeline: FigureTimeline, edge: FigureEdge, sourceLocation: SourceLocation = #_sourceLocation
) {
    for keyframe in timeline.keyframes {
        let pose = keyframe.joints
        #expect(
            !HumanRig.isOut(pose, at: edge) || FigureEdgePoses.route(leaving: pose) != nil,
            "out of a route at \(keyframe.time)", sourceLocation: sourceLocation
        )
        #expect(pose != legacyPeek, sourceLocation: sourceLocation)
    }
    for time in stride(from: 0, through: timeline.duration, by: 1.0 / 60) {
        #expect(!looksLikePeek(timeline.joints(at: time)), "peek at \(time)", sourceLocation: sourceLocation)
    }
}

@Suite("Sides — no rest: only the flag and the climb, in and out their own way")
struct SideRouteTests {
    private static let sides: [FigureEdge] = [.leading, .trailing]

    /// Poses a side play may start from: mid-flag, mid-climb, behind the card.
    private static let shownPoses: [FigureJoints?] = [
        nil, FigureEdgePoses.flagA, FigureEdgePoses.flagB, FigureEdgePoses.climbA, FigureEdgePoses.climbB,
        FigureEdgePoses.sideHidden,
    ]

    @Test("The legacy peek check catches the old pose")
    func legacyCheck() {
        #expect(looksLikePeek(legacyPeek))
        #expect(looksLikePeek(legacyPeek.with { $0.tilt = 6 }))
        for pose in [FigureEdgePoses.flagA, FigureEdgePoses.climbA, FigureEdgePoses.sideHidden, .rest] {
            #expect(!looksLikePeek(pose))
        }
        #expect(HumanRig.isOut(legacyPeek, at: .trailing) && FigureEdgePoses.route(leaving: legacyPeek) == nil)
    }

    @Test("No timeline at a side ever shows the peek: every action × entrance, relocating, chained, leaving",
          arguments: sides)
    func noPeekAtSides(edge: FigureEdge) {
        var generator = SystemRandomNumberGenerator()
        var count = 0
        for action in FigureAction.allCases {
            for entrance in [nil, FigureEntrance.spring, .climb] {
                let looped = FigureVariation.random(for: action, exit: .climb, using: &generator)
                let variations: [FigureVariation] = [
                    .standard, looped, looped.chained(continues: true),
                    .leaving(exit: .spring, using: &generator),
                ]
                for variation in variations {
                    for reduceMotion in [false, true] {
                        expectNeverStandsAtSide(FigureTimeline(
                            action: action, entrance: entrance, reduceMotion: reduceMotion, edge: edge,
                            variation: variation
                        ), edge: edge)
                        count += 1
                    }
                    // Played from the pose shown (a run cut short, a tap, a run going on).
                    for pose in Self.shownPoses {
                        for previous in [edge, .trailing, .leading, .top] {
                            for relocating in [false, true] {
                                expectNeverStandsAtSide(FigureTimeline(
                                    action: action, entrance: entrance, reduceMotion: false, edge: edge,
                                    relocating: relocating, from: previous, pose: pose, variation: variation
                                ), edge: edge)
                                count += 1
                            }
                        }
                    }
                }
            }
        }
        #expect(count > 1000)
    }

    @Test("Through the stage's request too (HumanRig), every side action", arguments: sides)
    func noPeekThroughHumanRig(edge: FigureEdge) {
        var generator = SystemRandomNumberGenerator()
        for action in FigureRepertoire.side + [.rest, .wave] {
            for pose in Self.shownPoses {
                for leaving in [false, true] {
                    let variation = leaving
                        ? FigureVariation.leaving(exit: .climb, using: &generator)
                        : FigureVariation.random(for: action, exit: .climb, using: &generator).chained(continues: true)
                    let play = HumanRig.timeline(FigurePlayRequest(
                        action: action.name, entrance: leaving ? nil : .climb, reduceMotion: false, edge: edge,
                        relocating: !leaving, previousEdge: edge, previousPose: pose, variation: variation
                    ))
                    expectNeverStandsAtSide(play, edge: edge)
                }
            }
        }
    }

    @Test("Any other action at a side is none: it stays behind the card", arguments: [
        FigureAction.rest, .wave, .run, .swing, .handstand,
    ])
    func otherActionsStayHidden(action: FigureAction) {
        for edge in Self.sides {
            let timeline = FigureTimeline(action: action, entrance: .spring, reduceMotion: false, edge: edge)
            #expect(timeline.keyframes.allSatisfy { !HumanRig.isOut($0.joints, at: edge) })
            #expect(timeline.walkWindow == nil && timeline.walkDistance == nil)
        }
        // And the side actions only play at a side: on the top they are the rest.
        for action in FigureRepertoire.side {
            let top = FigureTimeline(action: action, entrance: nil, reduceMotion: false)
            #expect(top == FigureTimeline(action: .rest, entrance: nil, reduceMotion: false))
        }
    }

    @Test("A chained side action ends in its route's held pose; the next step leaves its own way",
          arguments: FigureRepertoire.side)
    func chainedSideAction(action: FigureAction) throws {
        var generator = SystemRandomNumberGenerator()
        let route = try #require(FigureEdgePoses.route(for: action))
        for edge in Self.sides {
            let variation = FigureVariation.random(for: action, exit: .climb, using: &generator).chained(continues: true)
            #expect(variation.exit == nil)
            for entrance in [FigureEntrance.climb, .spring] {
                let chained = FigureTimeline(
                    action: action, entrance: entrance, reduceMotion: false, edge: edge, variation: variation
                )
                // Out its own way, held, never back to a rest.
                #expect(chained.keyframes.first?.joints == route.hidden)
                #expect(chained.final == route.held)
                #expect(chained.hiddenPause == nil)
                // The next action of the run comes out elsewhere: it leaves
                // from the held pose the action's own way (quicker), hidden
                // at the jump — no rest, no pause.
                for (next, nextEdge) in [(FigureAction.wave, FigureEdge.top), (.swing, .bottom), (.flag, .leading),
                                         (.climb, .trailing)] {
                    let relocation = FigureTimeline(
                        action: next, entrance: .climb, reduceMotion: false, edge: nextEdge,
                        relocating: true, from: edge, pose: chained.final
                    )
                    let jump = try #require(relocation.relocatesAt)
                    #expect(relocation.joints(at: 0) == route.held)
                    let leaving = relocation.keyframes.filter { $0.time <= jump + 1e-9 }.map(\.joints)
                    #expect(Array(leaving.dropFirst().prefix(route.exit.count)) == route.exit.map(\.joints))
                    #expect(route.exit.last?.joints == route.hidden)
                    #expect(abs(jump - route.exit.map(\.duration).reduce(0, +) * 0.6) < 1e-9)
                    #expect(relocation.hiddenPause == nil)
                    if nextEdge.isSide { expectNeverStandsAtSide(relocation, edge: nextEdge) }
                }
            }
        }
    }

    @Test("Leaving at a side: straight back the way of the action it is in, from the pose shown")
    func leavingAtSide() throws {
        var generator = SystemRandomNumberGenerator()
        for (pose, route) in [
            (FigureEdgePoses.flagA, FigureEdgePoses.flagRoute), (FigureEdgePoses.flagB, FigureEdgePoses.flagRoute),
            (FigureEdgePoses.climbA, FigureEdgePoses.climbRoute), (FigureEdgePoses.climbB, FigureEdgePoses.climbRoute),
        ] {
            for edge in Self.sides {
                let variation = FigureVariation.leaving(exit: .spring, using: &generator)
                // As the stage asks for it: the rest, leaving, from the pose shown.
                let timeline = HumanRig.timeline(FigurePlayRequest(
                    action: FigureRest.name, entrance: nil, reduceMotion: false, edge: edge,
                    previousEdge: edge, previousPose: pose, variation: variation
                ))
                #expect(timeline.keyframes.map(\.joints) == [pose] + route.exit.map(\.joints))
                #expect(abs(timeline.duration - route.exit.map(\.duration).reduce(0, +)) < 1e-9)
                #expect(timeline.final == route.hidden)
                #expect(timeline.hiddenPause == variation.hiddenPause)
                #expect(timeline.walkWindow == nil)
            }
        }
        // Already behind the card: nothing to play, only the pause.
        let hidden = FigureTimeline(
            action: .rest, entrance: nil, reduceMotion: false, edge: .trailing,
            from: .trailing, pose: FigureEdgePoses.sideHidden,
            variation: .leaving(exit: .climb, using: &generator)
        )
        #expect(hidden.keyframes.map(\.joints) == [FigureEdgePoses.sideHidden])
        #expect(hidden.hiddenPause != nil)
    }

    @Test("Plays without an action never pick a side: the top, else the bottom, else nowhere")
    func restingEdges() {
        #expect(FigureAnchorPicker.restingEdges(allowed: .all, restsAtSides: false) == .top)
        #expect(FigureAnchorPicker.restingEdges(allowed: .top, restsAtSides: false) == .top)
        #expect(FigureAnchorPicker.restingEdges(allowed: [.bottom, .leading, .trailing], restsAtSides: false) == .bottom)
        #expect(FigureAnchorPicker.restingEdges(allowed: [.leading, .trailing], restsAtSides: false).isEmpty)
        // A character with a rest at the sides (a custom one) keeps them.
        #expect(FigureAnchorPicker.restingEdges(allowed: .all, restsAtSides: true) == .all)
        #expect(!FigureGeometry.human.restsAtSides)
        #expect(!HumanRig.standard.geometry.restsAtSides)
    }

    private let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)
    private let sizes = PeekingFigureMetrics.standard.sizes

    @Test("Waiting and rest plays: the same anchor's top when it fits, else another top, never a side")
    func restingPlacement() {
        var generator = SystemRandomNumberGenerator()
        let allowed = FigureAnchorPicker.restingEdges(allowed: .all, restsAtSides: false)
        let hero = (id: "hero", rect: CGRect(x: 40, y: 200, width: 320, height: 200), edges: FigureEdges.all)
        let other = (id: "other", rect: CGRect(x: 40, y: 500, width: 320, height: 160), edges: FigureEdges.all)
        // Top off screen (sides fit).
        let high = (id: "high", rect: CGRect(x: 40, y: 10, width: 320, height: 200), edges: FigureEdges.all)
        let sides = (id: "sides", rect: CGRect(x: 40, y: 300, width: 320, height: 200), edges: FigureEdges([.leading, .trailing]))
        func place(_ current: String?, _ candidates: [(id: String, rect: CGRect, edges: FigureEdges)])
            -> (id: String, edge: FigureEdge)? {
            FigureAnchorPicker.restingPlacement(
                current: current, candidates: candidates, viewport: viewport, sizes: sizes,
                allowed: allowed, using: &generator
            )
        }
        for _ in 0..<100 {
            // At a side of "hero": its own top.
            #expect(place("hero", [hero, other, sides]).map { "\($0.id) \($0.edge)" } == "hero top")
            // Its top doesn't fit: another anchor's top, never a side.
            #expect(place("high", [high, other, sides]).map { "\($0.id) \($0.edge)" } == "other top")
            // Fresh (no current): any top.
            let fresh = place(nil, [hero, other, sides, high])
            #expect(fresh?.edge == .top && ["hero", "other"].contains(fresh?.id ?? ""))
            // Only sides fit: nowhere (it waits hidden).
            #expect(place("sides", [sides, high]) == nil)
        }
        // The sides fit "high" and "sides" in the free stage.
        for anchor in [high, sides] {
            #expect(FigureAnchorPicker.isEligible(rect: anchor.rect, edge: .trailing, viewport: viewport, sizes: sizes))
        }
    }
}
