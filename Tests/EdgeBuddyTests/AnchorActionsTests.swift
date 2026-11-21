import CoreGraphics
import SwiftUI
import Testing
@testable import EdgeBuddy

/// A deterministic generator for the picks below (SplitMix64).
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// A top-only test character with one opt-in action ("cheer").
private struct CheerBlob: FigureCharacter {
    struct Pose: FigureCharacterPose {
        var y: Double

        func interpolated(to other: Pose, _ t: Double) -> Pose {
            Pose(y: y + (other.y - y) * t)
        }
    }

    func box(at edge: FigureEdge) -> FigureCharacterBox {
        FigureCharacterBox(CGRect(x: 0, y: 0, width: 60, height: 60), edge: 60)
    }

    func actions(at edge: FigureEdge) -> [FigureCharacterAction<Pose>] {
        guard edge == .top else { return [] }
        let motion = FigureMotion(duration: 1, through: [Pose(y: 38), Pose(y: 30), Pose(y: 38)])
        return [
            FigureCharacterAction("bob", motion: motion),
            FigureCharacterAction("hop", motion: motion),
            FigureCharacterAction("cheer", motion: motion, optIn: true),
        ]
    }

    func restPose(at edge: FigureEdge) -> Pose { Pose(y: 38) }
    func hiddenPose(at edge: FigureEdge) -> Pose { Pose(y: 90) }
    func draw(_ pose: Pose, in context: inout GraphicsContext, color: Color) {}
}

@Suite("Per-anchor actions - an anchor's list, opt-in actions (the celebration)")
struct AnchorActionsTests {
    private let human = HumanRig.standard
    private let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)

    private func anchor(
        _ id: String, y: CGFloat, width: CGFloat = 360, edges: FigureEdges = .top, actions: [FigureActionName]? = nil
    ) -> FigureAnchorFrame {
        FigureAnchorFrame(
            id: AnyHashable(id), edges: edges, rect: CGRect(x: 20, y: y, width: width, height: 160),
            actions: actions.map { Set($0.map(\.rawValue)) }
        )
    }

    private func rules(_ anchors: [FigureAnchorFrame], character: AnyFigureCharacter = HumanRig.standard) -> FigureStageRules {
        FigureStageRules(
            anchors: anchors, viewport: viewport, character: character,
            metrics: PeekingFigureMetrics(height: PeekingFigureMetrics.defaultHeight, geometry: character.geometry)
        )
    }

    /// Plays `cycles` looped cycles the way `PeekingFigureView` picks them:
    /// a placement for an action, then an action there, never the last one
    /// twice in a row when there is another. Returns (anchor, edge, action).
    private func simulate(
        _ rules: FigureStageRules, cycles: Int = 400, seed: UInt64 = 7
    ) -> [(id: AnyHashable, edge: FigureEdge, action: String)] {
        var generator = SeededGenerator(state: seed)
        var current: AnyHashable?
        var currentEdge: FigureEdge?
        var last: String?
        var played: [(id: AnyHashable, edge: FigureEdge, action: String)] = []
        for _ in 0..<cycles {
            guard let place = rules.placement(
                excluding: current, edge: currentEdge, allowed: .all, after: last, using: &generator
            ), let rect = rules.anchors.first(where: { $0.id == place.id })?.rect else { break }
            let available = rules.actions(at: place.edge, on: rect, anchor: place.id, from: nil)
            let action = FigureRepertoire.next(
                after: last, from: available, fallback: FigureRest.name,
                weight: { rules.character.info($0, at: place.edge).weight }, using: &generator
            )
            played.append((place.id, place.edge, action))
            current = place.id
            currentEdge = place.edge
            last = action
        }
        return played
    }

    // MARK: - Names and the opt-in flag

    @Test("FigureActionName: one static per HumanFigure action, by name; string literals work")
    func names() {
        let statics: [FigureActionName] = [
            .wave, .jumpingJacks, .sideStretch, .march, .wormWalk, .handstand, .run, .nap, .slip, .celebrate,
            .champagne, .flex, .swing, .pullUp, .flag, .climb,
        ]
        #expect(statics.map(\.rawValue) == FigureAction.allCases.filter { $0 != .rest }.map(\.name))
        #expect(FigureActionName.celebrate == "celebrate")
        #expect(FigureActionName.champagne == "champagne")
        #expect(FigureActionName.flex == "flex")
        #expect(FigureActionName("float") == FigureActionName(rawValue: "float"))
    }

    @Test("The celebrations are the human's only opt-in actions, also through the protocol")
    func humanOptIn() {
        let celebrations: Set<String> = ["celebrate", "champagne", "flex"]
        #expect(FigureRepertoire.optIn == [.celebrate, .champagne, .flex])
        #expect(human.optInActions == celebrations)
        for edge in FigureEdge.allCases {
            for action in HumanFigure().actions(at: edge) {
                #expect(action.isOptIn == celebrations.contains(action.name))
            }
        }
        #expect(FigureCharacterAction<CheerBlob.Pose>("x", motion: FigureMotion(duration: 1) { _ in .init(y: 0) })
            .isOptIn == false)
    }

    // MARK: - What an anchor offers

    @Test("Default anchors: the top repertoire with the nap and the slip, never the celebrations; other edges unchanged")
    func defaultRepertoire() {
        #expect(human.actions(at: .top, room: 1000, atScreenEdge: false)
            == ["wave", "jumpingJacks", "sideStretch", "march", "wormWalk", "handstand", "run", "nap", "slip"])
        #expect(human.actions(at: .bottom, room: 1000, atScreenEdge: false) == ["swing", "pullUp"])
        #expect(human.actions(at: .trailing, room: 1000, atScreenEdge: false) == ["flag", "climb"])
        #expect(human.actions(at: .trailing, room: 1000, atScreenEdge: true) == ["climb"])
    }

    @Test("A list: only its actions, opt-in included, each at its own edges; room and the screen's edge still filter")
    func listed() {
        let only = { (names: Set<String>, edge: FigureEdge, room: Double, atScreenEdge: Bool) in
            human.actions(at: edge, room: room, atScreenEdge: atScreenEdge, listed: names)
        }
        #expect(only(["celebrate"], .top, 1000, false) == ["celebrate"])
        #expect(only(["celebrate"], .bottom, 1000, false).isEmpty)
        #expect(only(["celebrate"], .trailing, 1000, false).isEmpty)
        #expect(only(["wave", "flag"], .top, 1000, false) == ["wave"])
        #expect(only(["wave", "flag"], .trailing, 1000, false) == ["flag"])
        // By the screen's edge a side only climbs: the flag is out.
        #expect(only(["wave", "flag"], .trailing, 1000, true).isEmpty)
        // The worm walk needs room along the top.
        #expect(only(["wormWalk", "celebrate"], .top, 0, false) == ["celebrate"])
        // The rest is no action; unknown names add nothing.
        #expect(only(["rest", "moonwalk"], .top, 1000, false).isEmpty)
        #expect(only([], .top, 1000, false).isEmpty)
    }

    @Test("A custom character's opt-in action plays only where an anchor lists it")
    func customOptIn() {
        let blob = AnyFigureCharacter(CheerBlob())
        #expect(blob.optInActions == ["cheer"])
        #expect(blob.geometry.supportedEdges == .top)
        #expect(blob.actions(at: .top, room: 1000, atScreenEdge: false) == ["bob", "hop"])
        #expect(blob.actions(at: .top, room: 1000, atScreenEdge: false, listed: ["cheer"]) == ["cheer"])
        #expect(blob.actions(at: .top, room: 1000, atScreenEdge: false, listed: ["bob", "cheer"]) == ["bob", "cheer"])
        let played = simulate(rules([anchor("a", y: 120), anchor("p", y: 400, actions: ["cheer"])], character: blob))
        #expect(played.allSatisfy { ($0.id == AnyHashable("p")) == ($0.action == "cheer") })
    }

    // MARK: - Picks on a screen

    @Test("Celebrate never comes up on anchors that didn't ask for it", arguments: [UInt64(1), 2, 3])
    func neverWithoutOptIn(seed: UInt64) {
        let played = simulate(rules([
            anchor("hero", y: 120, edges: .all),
            anchor("stats", y: 400),
            anchor("week", y: 600, edges: [.top, .bottom]),
        ]), seed: seed)
        #expect(played.count == 400)
        #expect(!played.contains { $0.action == "celebrate" })
        // Still the whole default repertoire at every edge.
        #expect(Set(played.map(\.edge)) == Set(FigureEdge.allCases))
        #expect(Set(played.filter { $0.edge == .top }.map(\.action))
            == ["wave", "jumpingJacks", "sideStretch", "march", "wormWalk", "handstand", "run", "nap", "slip"])
    }

    @Test("The podium only celebrates, and only the podium celebrates", arguments: [UInt64(1), 2, 3])
    func podium(seed: UInt64) {
        let played = simulate(rules([
            anchor("hero", y: 120, edges: .all),
            anchor("podium", y: 420, edges: .all, actions: [.celebrate]),
        ]), seed: seed)
        let onPodium = played.filter { $0.id == AnyHashable("podium") }
        #expect(!onPodium.isEmpty)
        // Its other edges have nothing listed: only its top is used.
        #expect(onPodium.allSatisfy { $0.edge == .top && $0.action == "celebrate" })
        #expect(!played.contains { $0.id != AnyHashable("podium") && $0.action == "celebrate" })
    }

    @Test("A podium alone celebrates every cycle (the same action again: nothing else is allowed)")
    func podiumAlone() {
        let played = simulate(rules([anchor("podium", y: 300, edges: .all, actions: [.celebrate])]), cycles: 50)
        #expect(played.count == 50)
        #expect(played.allSatisfy { $0.edge == .top && $0.action == "celebrate" })
    }

    @Test("A list restricts picks to its actions")
    func restricts() {
        let played = simulate(rules([
            anchor("a", y: 120, edges: .all, actions: [.wave, .swing]),
            anchor("b", y: 420, edges: .all, actions: [.march]),
        ]))
        #expect(Set(played.filter { $0.id == AnyHashable("a") }.map(\.action)) == ["wave", "swing"])
        #expect(Set(played.filter { $0.id == AnyHashable("a") }.map(\.edge)) == [.top, .bottom])
        #expect(Set(played.filter { $0.id == AnyHashable("b") }.map(\.action)) == ["march"])
        #expect(played.allSatisfy { $0.edge == .top || $0.edge == .bottom })
    }

    @Test("Nothing playable on an anchor: used only when no other anchor has an action, then it rests")
    func nothingPlayable() {
        // A worm walk on a card too narrow for it, and an empty list.
        let narrow = anchor("narrow", y: 120, width: 120, actions: [.wormWalk])
        let empty = anchor("empty", y: 340, actions: [])
        let played = simulate(rules([narrow, empty, anchor("free", y: 560)]))
        #expect(played.allSatisfy { $0.id == AnyHashable("free") })
        let alone = simulate(rules([empty]), cycles: 5)
        #expect(alone.count == 5)
        #expect(alone.allSatisfy { $0.id == AnyHashable("empty") && $0.action == FigureRest.name })
    }

    @Test("A run on the podium goes on celebrating from where it stands")
    func runOnPodium() {
        let podium = anchor("podium", y: 300, actions: [.celebrate])
        let rules = rules([podium, anchor("hero", y: 520)])
        for spot in [0.0, 0.5, 1.0] {
            #expect(rules.actions(at: .top, on: podium.rect, anchor: podium.id, from: spot) == ["celebrate"])
        }
        #expect(!rules.actions(at: .top, on: CGRect(x: 20, y: 520, width: 360, height: 160), anchor: AnyHashable("hero"), from: 0.5)
            .contains("celebrate"))
    }

    @Test("Plays without an action rest on any anchor, whatever its list")
    func restingIgnoresTheList() throws {
        let empty = anchor("empty", y: 300, edges: .all, actions: [])
        var generator = SeededGenerator(state: 3)
        let place = try #require(rules([empty]).restingPlacement(current: empty.id, allowed: .top, using: &generator))
        #expect(place.id == empty.id && place.edge == .top)
    }

    @Test("The picker prefers a place with an action over a fresh one elsewhere")
    func offersAny() {
        let candidates = [
            (id: 0, rect: CGRect(x: 20, y: 120, width: 360, height: 160), edges: FigureEdges.top),
            (id: 1, rect: CGRect(x: 20, y: 420, width: 360, height: 160), edges: FigureEdges.top),
        ]
        var generator = SeededGenerator(state: 11)
        for _ in 0..<50 {
            let place = FigureAnchorPicker.nextPlacement(
                current: 1, candidates: candidates, viewport: viewport, sizes: PeekingFigureMetrics.standard.sizes,
                offersAny: { id, _, _ in id == 1 }, using: &generator
            )
            #expect(place?.id == 1)
        }
    }
}
