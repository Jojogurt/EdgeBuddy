/// The name of an action a character plays at an edge, for the actions an
/// anchor allows (`figureAnchor(_:edges:actions:)`).
///
/// ``HumanFigure``'s actions are the static members. For a character of
/// your own use its action's ``FigureCharacterAction/name``; a string
/// literal works:
///
/// ```swift
/// PodiumCard().figureAnchor("podium", actions: [.celebrate])
/// HeroCard().figureAnchor("hero", edges: .all, actions: ["float", "spin"])
/// ```
///
/// The rest (standing on a top, hanging under a bottom) is not an action:
/// every anchor allows it, "rest" in a list adds nothing.
public struct FigureActionName: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The action's name (`FigureCharacterAction.name`).
    public let rawValue: String

    /// The action called `rawValue`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// The action called `name`.
    public init(_ name: String) {
        self.init(rawValue: name)
    }

    /// The action called `value`.
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    private init(_ action: FigureAction) {
        self.init(rawValue: action.name)
    }

    /// Top: a greeting, one arm up.
    public static let wave = Self(FigureAction.wave)
    /// Top: jumping jacks.
    public static let jumpingJacks = Self(FigureAction.jumpingJacks)
    /// Top: a side bend, arms up.
    public static let sideStretch = Self(FigureAction.sideStretch)
    /// Top: marching in place.
    public static let march = Self(FigureAction.march)
    /// Top: lies down on the edge and inches along it like a caterpillar
    /// (needs room along the top).
    public static let wormWalk = Self(FigureAction.wormWalk)
    /// Top: cartwheels into a handstand.
    public static let handstand = Self(FigureAction.handstand)
    /// Top: runs along the edge to another spot.
    public static let run = Self(FigureAction.run)
    /// Top: a winner on the podium, hops with both arms up in a V. Opt-in:
    /// played only on anchors that list it.
    public static let celebrate = Self(FigureAction.celebrate)
    /// Top: a bottle of champagne, shaken hard until it goes off to one
    /// side, then shaken again and off to the other, then a swig. Opt-in:
    /// played only on anchors that list it.
    public static let champagne = Self(FigureAction.champagne)
    /// Top: a bodybuilder going through the poses (double biceps, most
    /// muscular, side chest, one biceps with the other arm down, abs and thigh). Opt-in: played only
    /// on anchors that list it.
    public static let flex = Self(FigureAction.flex)
    /// Bottom: swings on its hands.
    public static let swing = Self(FigureAction.swing)
    /// Bottom: pulls itself up to the edge.
    public static let pullUp = Self(FigureAction.pullUp)
    /// Sides: a human flag beside the card (not at the screen's edge).
    public static let flag = Self(FigureAction.flag)
    /// Sides: climbs up the outside of the card's edge (needs room along the side).
    public static let climb = Self(FigureAction.climb)
}
