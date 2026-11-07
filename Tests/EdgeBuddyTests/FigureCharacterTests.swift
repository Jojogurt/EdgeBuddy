import CoreGraphics
import SwiftUI
import Testing
@testable import EdgeBuddy

/// A ghost-like test character: no limbs, its own pose (an offset and a
/// squash), top and sides only.
struct BlobFigure: FigureCharacter {
    struct Pose: FigureCharacterPose {
        var x: Double
        var y: Double
        var squash: Double = 1

        func interpolated(to other: Pose, _ t: Double) -> Pose {
            Pose(x: x + (other.x - x) * t, y: y + (other.y - y) * t, squash: squash + (other.squash - squash) * t)
        }
    }

    func box(at edge: FigureEdge) -> FigureCharacterBox {
        switch edge {
        case .top: FigureCharacterBox(CGRect(x: 0, y: 0, width: 60, height: 60), edge: 60)
        case .bottom: FigureCharacterBox(CGRect(x: 0, y: 0, width: 80, height: 40), edge: 0)
        case .leading, .trailing: FigureCharacterBox(CGRect(x: 0, y: 0, width: 50, height: 70), edge: 0)
        }
    }

    func actions(at edge: FigureEdge) -> [FigureCharacterAction<Pose>] {
        switch edge {
        case .top:
            [
                FigureCharacterAction(
                    "bob", motion: FigureMotion(duration: 1, through: [
                        Pose(x: 30, y: 38), Pose(x: 30, y: 30), Pose(x: 30, y: 38),
                    ]), repeats: 2...3
                ),
                FigureCharacterAction(
                    "boo", motion: FigureMotion(duration: 0.8) { t in Pose(x: 30, y: 34, squash: 1 + t) }, hold: 0.6
                ),
                FigureCharacterAction(
                    "drift", motion: FigureMotion(duration: 1, through: [Pose(x: 30, y: 38)]),
                    repeats: 2...4, travel: 25
                ),
            ]
        case .bottom:
            []
        case .leading, .trailing:
            [
                FigureCharacterAction("peek", motion: FigureMotion(duration: 1, through: [Pose(x: 25, y: 35)])),
                FigureCharacterAction(
                    "haunt", motion: FigureMotion(duration: 0.9, through: [Pose(x: 25, y: 35)]),
                    repeats: 2...3, travel: 20, playsAtScreenEdge: false
                ),
            ]
        }
    }

    func restPose(at edge: FigureEdge) -> Pose {
        edge == .top ? Pose(x: 30, y: 38) : Pose(x: 25, y: 35)
    }

    func hiddenPose(at edge: FigureEdge) -> Pose {
        edge == .top ? Pose(x: 30, y: 90) : Pose(x: -30, y: 35)
    }

    func draw(_ pose: Pose, in context: inout GraphicsContext, color: Color) {
        context.fill(Path(ellipseIn: CGRect(x: pose.x - 12, y: pose.y - 16 * pose.squash, width: 24, height: 32)), with: .color(color))
    }
}

/// The blob's sequence of `play`.
private func sequence(_ play: FigurePlay) throws -> FigureSequence<BlobFigure.Pose> {
    try #require(play.base as? FigureSequence<BlobFigure.Pose>)
}

@Suite("Characters — the protocol, the erased wrapper and HumanFigure behind it")
struct FigureCharacterTests {
    private let blob = AnyFigureCharacter(BlobFigure())
    private let human = AnyFigureCharacter(HumanFigure())

    @Test("HumanFigure goes through the human rig: same geometry, repertoire and timelines")
    func humanIsTheRig() throws {
        #expect(human.typeID == ObjectIdentifier(HumanFigure.self))
        #expect(human.geometry == .human)
        #expect(PeekingFigureMetrics(height: 56, geometry: human.geometry) == .standard)
        for edge in FigureEdge.allCases {
            let room = 1000.0
            #expect(human.actions(at: edge, room: room, atScreenEdge: false)
                == FigureRepertoire.actions(for: edge, room: room).map(\.name))
            #expect(human.actions(at: edge, room: room, atScreenEdge: true)
                == FigureRepertoire.actions(for: edge, room: room, atScreenEdge: true).map(\.name))
            for action in FigureRepertoire.actions(for: edge) {
                let variation = FigureVariation(holdBefore: 0.5, repeats: 2, holdAfter: 0.7, exit: .spring, hiddenPause: 1)
                let play = human.play(FigurePlayRequest(
                    action: action.name, entrance: .climb, reduceMotion: false, edge: edge,
                    relocating: true, previousEdge: .top, previousPose: FigureJoints.rest, tempo: 1.2,
                    variation: variation
                ))
                let direct = FigureTimeline(
                    action: action, entrance: .climb, reduceMotion: false, edge: edge, relocating: true,
                    from: .top, pose: nil, tempo: 1.2, variation: variation
                )
                #expect(play.base as? FigureTimeline == direct)
                let info = human.info(action.name, at: edge)
                #expect(info.travelPerBeat == FigureTimeline.travel(action, repeats: 1))
                #expect(info.repeatRange == FigureVariation.repeatRange(action))
                #expect(info.defaultRepeats == FigureTimeline.canvasRepeats(action))
            }
        }
    }

    @Test("A side's shown pose is where the human leaves from (mid-climb)")
    func humanLeavesFromTheShownPose() {
        let request = FigurePlayRequest(
            action: "wave", entrance: .spring, reduceMotion: false, relocating: true,
            previousEdge: .trailing, previousPose: FigureEdgePoses.climbA
        )
        let direct = FigureTimeline(
            action: .wave, entrance: .spring, reduceMotion: false, relocating: true,
            from: .trailing, pose: FigureEdgePoses.climbA
        )
        #expect(human.play(request).base as? FigureTimeline == direct)
    }

    @Test("Human frames: the rig's pose, taps once out, never mirrored by the stage")
    func humanFrames() throws {
        let play = human.play(FigurePlayRequest(action: "wave", entrance: .spring, reduceMotion: false))
        #expect(try #require(human.frame(play, at: 0, edge: .top, heading: 0)).isOut == false)
        let out = try #require(human.frame(play, at: play.duration, edge: .top, heading: -1))
        #expect(out.isOut && !out.isMirrored)
        // A play of another character type draws nothing.
        #expect(human.frame(blob.play(FigurePlayRequest(action: "bob", entrance: nil, reduceMotion: false)),
                            at: 0, edge: .top, heading: 0) == nil)
    }

    @Test("HumanFigure describes its repertoire through the protocol")
    func humanDescription() {
        let figure = HumanFigure()
        #expect(figure.referenceHeight == 108)
        #expect(figure.box(at: .bottom) == FigureGeometry.human.bottom)
        for edge in FigureEdge.allCases {
            #expect(figure.actions(at: edge).map(\.name) == FigureRepertoire.actions(for: edge).map(\.name))
            #expect(figure.restPose(at: edge).joints == FigureTimeline.restPose(edge))
            let entrance = figure.entrance(at: edge)
            #expect(entrance?.pose(at: 0).joints == FigureTimeline.hiddenPose(.spring, edge: edge))
            #expect(entrance?.pose(at: entrance?.duration ?? 0).joints == FigureTimeline.restPose(edge))
        }
        let climb = figure.actions(at: .trailing).first { $0.name == "climb" }
        #expect(climb?.travel ?? 0 > 0 && climb?.playsAtScreenEdge == true)
        #expect(figure.actions(at: .trailing).first { $0.name == "flag" }?.playsAtScreenEdge == false)
    }

    @Test("Geometry of a custom character: its boxes, its edges, its screen-edge rule")
    func customGeometry() {
        let geometry = blob.geometry
        #expect(geometry.referenceHeight == 60)
        #expect(geometry.supportedEdges == [.top, .leading, .trailing])
        // Only "peek" plays at the screen's edge, and it doesn't travel.
        #expect(geometry.screenEdgeSideRoom == 0)
        let metrics = PeekingFigureMetrics(height: 60, geometry: geometry)
        #expect(metrics.scale == 1)
        #expect(metrics.size(for: .trailing) == CGSize(width: 50, height: 70))
        // The bottom is unused: only the top's width counts.
        #expect(metrics.width == 60)
        #expect(metrics.sizes.figureHeight == 60)
        #expect(metrics.sideOverlap(at: .trailing) == 0)
        #expect(metrics.sizes.climbMinHeight == metrics.sizes.sideMinHeight.rounded(.up))
    }

    @Test("Actions per edge: room to travel and the screen's edge filter them")
    func customActions() {
        #expect(blob.actions(at: .top, room: 1000, atScreenEdge: false) == ["bob", "boo", "drift"])
        // The drift needs 2 × 25 units.
        #expect(blob.actions(at: .top, room: 49, atScreenEdge: false) == ["bob", "boo"])
        #expect(blob.actions(at: .bottom, room: 1000, atScreenEdge: false).isEmpty)
        #expect(blob.actions(at: .trailing, room: 1000, atScreenEdge: true) == ["peek"])
        #expect(blob.info("drift", at: .top) == FigureActionInfo(travelPerBeat: 25, repeatRange: 2...4, defaultRepeats: 2))
        #expect(blob.info("bob", at: .top).travelPerBeat == nil)
        #expect(blob.pinnedAction("boo", at: .top) == "boo")
        #expect(blob.pinnedAction("boo", at: .leading) == FigureActionName.rest)
        #expect(blob.pinnedAction("wave", at: .top) == FigureActionName.rest)
    }

    @Test("A play: rise from hidden, beats, back behind the card")
    func customPlay() throws {
        let figure = BlobFigure()
        let variation = FigureVariation(holdBefore: 0.4, repeats: 3, holdAfter: 0.5, exit: .spring, hiddenPause: 1.5)
        let play = blob.play(FigurePlayRequest(action: "bob", entrance: .climb, reduceMotion: false, variation: variation))
        let seq = try sequence(play)
        let rise = FigureSequence<BlobFigure.Pose>.riseDuration
        #expect(seq.pose(at: 0) == figure.hiddenPose(at: .top))
        #expect(seq.pose(at: rise) == figure.restPose(at: .top))
        // Entrance, hold, 3 beats (bob starts and ends at rest: no blends), hold, exit.
        #expect(abs(play.duration - (rise + 0.4 + 3 + 0.5 + rise)) < 1e-9)
        #expect(seq.pose(at: play.duration) == figure.hiddenPose(at: .top))
        #expect(play.hiddenPause == 1.5)
        #expect(play.walkWindow == nil && play.relocatesAt == nil)
        // Mid-beat: the bob's top.
        #expect(abs(seq.pose(at: rise + 0.4 + 0.5).y - 30) < 1e-9)
        // Taps: not while hidden, yes once out, not after leaving.
        #expect(!seq.isOut(at: 0.1))
        #expect(seq.isOut(at: rise + 0.1))
        #expect(!seq.isOut(at: play.duration))
        // The holds are still: the clock stops there.
        #expect(play.stillWindows.contains { abs($0.lowerBound - rise) < 1e-9 && abs($0.upperBound - (rise + 0.4)) < 1e-9 })
        // The hold frame: half-way through the first beat.
        #expect(abs((play.holdTime ?? 0) - (rise + 0.4 + 0.5)) < 1e-9)
    }

    @Test("Blends into and out of an action that doesn't start at rest; tempo scales the beats")
    func customBlendAndTempo() throws {
        let play = blob.play(FigurePlayRequest(action: "boo", entrance: nil, reduceMotion: false, tempo: 2))
        let seq = try sequence(play)
        let blend = FigureSequence<BlobFigure.Pose>.blendDuration
        // No entrance: rest, blend in, one beat, blend out — all at double speed.
        #expect(abs(play.duration - (blend + 0.8 + blend) / 2) < 1e-9)
        #expect(seq.pose(at: 0) == BlobFigure().restPose(at: .top))
        #expect(seq.pose(at: play.duration) == BlobFigure().restPose(at: .top))
        // Hold frame at 0.6 s into the beat, at tempo 2.
        #expect(abs((play.holdTime ?? 0) - (blend + 0.6) / 2) < 1e-9)
        #expect(abs(seq.pose(at: play.holdTime ?? 0).squash - 1.6) < 1e-9)
    }

    @Test("Travelling actions walk exactly travel × beats; the stage mirrors heading left")
    func customTravel() throws {
        let play = blob.play(FigurePlayRequest(
            action: "drift", entrance: nil, reduceMotion: false, variation: FigureVariation(repeats: 3)
        ))
        #expect(play.walkDistance == 75)
        let window = try #require(play.walkWindow)
        #expect(abs(window.upperBound - window.lowerBound - 3) < 1e-9)
        #expect(play.walkProgress(at: window.lowerBound) == 0)
        #expect(abs((play.walkProgress(at: (window.lowerBound + window.upperBound) / 2) ?? 0) - 0.5) < 1e-9)
        #expect(play.walkProgress(at: window.upperBound + 1) == 1)
        #expect(try #require(blob.frame(play, at: 1, edge: .top, heading: -0.3)).isMirrored)
        #expect(try #require(blob.frame(play, at: 1, edge: .top, heading: 0.3)).isMirrored == false)
        #expect(try #require(blob.frame(play, at: 1, edge: .trailing, heading: -0.3)).isMirrored == false)
    }

    @Test("Relocating ducks from the shown pose to the old edge's hidden pose, then comes out")
    func customRelocation() throws {
        let figure = BlobFigure()
        let shown = BlobFigure.Pose(x: 40, y: 20)
        let play = blob.play(FigurePlayRequest(
            action: "peek", entrance: .spring, reduceMotion: false, edge: .trailing,
            relocating: true, previousEdge: .top, previousPose: shown
        ))
        let seq = try sequence(play)
        let jump = try #require(play.relocatesAt)
        #expect(seq.pose(at: 0) == shown)
        #expect(seq.pose(at: jump) == figure.hiddenPose(at: .top))
        #expect(seq.pose(at: jump + 0.05) == figure.hiddenPose(at: .trailing))
        #expect(!seq.isOut(at: jump + 0.05))
    }

    @Test("Reduce Motion: a fade into the rest pose, nothing else")
    func customReduceMotion() throws {
        let play = blob.play(FigurePlayRequest(action: "bob", entrance: .climb, reduceMotion: true))
        let seq = try sequence(play)
        #expect(abs(play.duration - 0.2) < 1e-9)
        #expect(play.opacity(at: 0) == 0 && play.opacity(at: 0.2) == 1)
        #expect(seq.pose(at: 0.1) == BlobFigure().restPose(at: .top))
        #expect(play.holdTime == nil && play.walkWindow == nil && play.hiddenPause == nil)
        #expect(play.stillWindows.isEmpty)
    }

    @Test("Low Power / rest: out to the rest pose and stands")
    func customRest() throws {
        let play = blob.play(FigurePlayRequest(action: FigureActionName.rest, entrance: .spring, reduceMotion: false))
        let seq = try sequence(play)
        #expect(abs(play.duration - FigureSequence<BlobFigure.Pose>.riseDuration) < 1e-9)
        #expect(seq.pose(at: play.duration) == BlobFigure().restPose(at: .top))
        #expect(play.holdTime == nil)
    }

    @Test("FigureMotion through poses: ends exact, eased steps, clamped time")
    func motionThroughPoses() {
        let motion = FigureMotion(duration: 2, through: [
            BlobFigure.Pose(x: 0, y: 0), BlobFigure.Pose(x: 10, y: 0), BlobFigure.Pose(x: 10, y: 10),
        ])
        #expect(motion.pose(at: -1) == BlobFigure.Pose(x: 0, y: 0))
        #expect(motion.pose(at: 1) == BlobFigure.Pose(x: 10, y: 0))
        #expect(motion.pose(at: 2) == BlobFigure.Pose(x: 10, y: 10))
        #expect(motion.pose(at: 5) == BlobFigure.Pose(x: 10, y: 10))
        #expect(abs(motion.pose(at: 0.5).x - 5) < 1e-9)
        let action = FigureCharacterAction("a", motion: motion, repeats: 0...2, travel: -3)
        #expect(action.repeats == 1...2 && action.travel == 0 && action.minimumRoom == 0)
    }
}

@Suite("Pins by action name")
struct FigurePinActionTests {
    private let anchors = [
        FigureAnchorFrame(id: AnyHashable("hero"), edges: .all, rect: CGRect(x: 40, y: 120, width: 320, height: 200)),
    ]
    private let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)

    private func resolve(_ pin: FigurePin, _ character: AnyFigureCharacter) -> FigurePinnedPlay? {
        let metrics = PeekingFigureMetrics(height: 56, geometry: character.geometry)
        return FigurePinnedPlay.resolve(
            pin, anchors: anchors, viewport: viewport, metrics: metrics, style: .standard, character: character
        )
    }

    @Test("A pose is its action's name; an action name of the human is its pose")
    func poseAndAction() {
        #expect(FigurePin(anchor: "hero", pose: .flag).action == "flag")
        #expect(FigurePin(anchor: "hero", action: "handstand").pose == .handstand)
        #expect(FigurePin(anchor: "hero", action: "boo").pose == nil)
        #expect(FigurePin.singleCard(action: "boo").anchor == AnyHashable(SoloAnchor.id))
        for pose in FigurePose.allCases { #expect(FigurePose(rawValue: pose.rawValue) == pose) }
    }

    @Test("A custom character's pin plays the named action and freezes at its hold")
    func customPin() throws {
        let blob = AnyFigureCharacter(BlobFigure())
        let play = try #require(resolve(FigurePin(anchor: "hero", action: "boo", animated: false), blob))
        #expect(play.action == "boo")
        let pose = try #require((play.timeline.base as? FigureSequence<BlobFigure.Pose>)?.pose(at: play.holdTime))
        #expect(abs(pose.squash - 1.6) < 1e-9)
        // Not at that edge: rests. An edge it never plays at: no pin (free stage).
        #expect(try #require(resolve(FigurePin(anchor: "hero", edge: .trailing, action: "boo"), blob)).action == "rest")
        #expect(resolve(FigurePin(anchor: "hero", edge: .bottom, action: "boo"), blob) == nil)
    }

    @Test("The human's pin by name is the pin by pose")
    func humanPinByName() throws {
        let human = AnyFigureCharacter(HumanFigure())
        let byName = try #require(resolve(FigurePin(anchor: "hero", edge: .trailing, action: "flag"), human))
        let byPose = try #require(resolve(FigurePin(anchor: "hero", edge: .trailing, pose: .flag), human))
        #expect(byName == byPose)
        #expect(byName.timeline.joints(at: byName.holdTime) == FigureEdgePoses.flagA)
    }
}
