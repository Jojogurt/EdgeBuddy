/// How the figure gets onto an anchor's edge. Never instantly: it always
/// comes out from behind the view.
public enum FigureEntrance: Equatable, Sendable {
    /// Hands grab the edge, it hangs behind the view, pulls itself up, puts a
    /// knee on the edge and stands up (~1.4 s).
    case climb
    /// Springs straight up from behind the view with a small overshoot.
    case spring
}

/// Everything about the figure a screen may tune; the action itself is
/// drawn at random by the stage.
public struct FigureStyle: Equatable, Sendable {
    /// How the figure comes out from behind an anchor (and, played in
    /// reverse, how it goes back).
    public var entrance: FigureEntrance
    /// Playback speed: 2 = twice as fast, 0.5 = half speed.
    public var tempo: Double

    /// A style with the given entrance and tempo.
    ///
    /// - Parameters:
    ///   - entrance: how the figure comes out; `.climb` by default.
    ///   - tempo: playback speed, 1 by default.
    public init(entrance: FigureEntrance = .climb, tempo: Double = 1) {
        self.entrance = entrance
        self.tempo = tempo
    }

    /// The default style: it climbs out, at normal speed.
    public static let standard = FigureStyle()
}
