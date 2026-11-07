import SwiftUI

/// What the figure's head is drawn as.
public enum FigureHead: Sendable {
    /// A filled circle, the default.
    case circle
    /// An SF Symbol, tinted with the head colour.
    case symbol(String)
    /// A short text — typically one emoji. Emoji keep their own colours.
    case text(String)
    /// Any image, fitted into the head's square. Use
    /// `.renderingMode(.template)` on it to tint it with the head colour.
    case image(Image)
}

/// How the figure looks, apart from where it is and what it does: the head,
/// the thickness of the body and the colour of each part
/// (`figureAppearance(_:)`).
///
/// The motion, the layout (how much room the figure needs at an edge) and
/// hit testing are the same for every appearance; only the drawing changes.
/// Sizes are therefore clamped to a range that stays inside the figure's
/// footprint.
public struct FigureAppearance: Sendable {
    /// What the head is drawn as.
    public var head: FigureHead
    /// Size of the head relative to the default, 0.6…1.5.
    public var headScale: Double {
        didSet { headScale = Self.clamp(headScale) }
    }
    /// Thickness of the arms and legs relative to the default, 0.6…1.5.
    public var limbScale: Double {
        didSet { limbScale = Self.clamp(limbScale) }
    }
    /// Thickness of the torso relative to the default, 0.6…1.5.
    public var torsoScale: Double {
        didSet { torsoScale = Self.clamp(torsoScale) }
    }
    /// Colour of the head; nil = the figure's colour.
    public var headColor: Color?
    /// Colour of the torso; nil = the figure's colour.
    public var torsoColor: Color?
    /// Colour of the arms; nil = the figure's colour.
    public var armColor: Color?
    /// Colour of the legs; nil = the figure's colour.
    public var legColor: Color?
    /// true = a `symbol`, `text` or `image` head is flipped when the figure
    /// faces left; false (default) keeps it as drawn (right for text).
    public var mirrorsHead: Bool
    /// A figure of your own that replaces the drawing altogether; nil = the
    /// default figure, tuned by the other fields. With a character the head,
    /// scale and colour fields above are ignored (the character gets
    /// `figureColor(_:)` and does the rest itself).
    public var character: (any FigureCharacter)?

    /// An appearance; every parameter has the default look.
    public init(
        head: FigureHead = .circle, headScale: Double = 1, limbScale: Double = 1,
        torsoScale: Double = 1, headColor: Color? = nil, torsoColor: Color? = nil,
        armColor: Color? = nil, legColor: Color? = nil, mirrorsHead: Bool = false,
        character: (any FigureCharacter)? = nil
    ) {
        self.character = character
        self.head = head
        self.headScale = Self.clamp(headScale)
        self.limbScale = Self.clamp(limbScale)
        self.torsoScale = Self.clamp(torsoScale)
        self.headColor = headColor
        self.torsoColor = torsoColor
        self.armColor = armColor
        self.legColor = legColor
        self.mirrorsHead = mirrorsHead
    }

    /// The default look: a round head, one colour.
    public static let standard = FigureAppearance()

    static let scaleRange = 0.6...1.5

    private static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(max(value, scaleRange.lowerBound), scaleRange.upperBound) : 1
    }
}

extension EnvironmentValues {
    /// The figure's look (`figureAppearance(_:)`).
    @Entry var figureAppearance: FigureAppearance = .standard
}

extension View {
    /// Sets how every figure in this view hierarchy looks: the head (a
    /// symbol, an emoji or an image instead of the circle), the thickness of
    /// head, limbs and torso, and a colour per part.
    ///
    /// ```swift
    /// .figureAppearance(FigureAppearance(head: .text("🐻"), headScale: 1.4, armColor: .orange))
    /// ```
    ///
    /// - Parameter appearance: the look; `.standard` restores the default.
    public func figureAppearance(_ appearance: FigureAppearance) -> some View {
        environment(\.figureAppearance, appearance)
    }
}
