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
    /// How long the figure stays hidden after its stage appears before it
    /// first comes out, seconds — a random value in this range each time,
    /// scaled by 1/`tempo`. A single value (`1...1`) is fixed; `0...0` comes
    /// out at once. Only the first entrance waits: later cycles have their
    /// own pauses and a tap moves it at once.
    public var appearDelay: ClosedRange<Double>

    /// The default `appearDelay`, seconds.
    public static let defaultAppearDelay: ClosedRange<Double> = 0.8...2.0

    /// A style with the given entrance, tempo and first-entrance delay.
    ///
    /// - Parameters:
    ///   - entrance: how the figure comes out; `.climb` by default.
    ///   - tempo: playback speed, 1 by default.
    ///   - appearDelay: seconds hidden before the first entrance after the
    ///     stage appears, drawn at random from this range; 0.8…2 by default,
    ///     `0...0` for none.
    public init(
        entrance: FigureEntrance = .climb, tempo: Double = 1,
        appearDelay: ClosedRange<Double> = FigureStyle.defaultAppearDelay
    ) {
        self.entrance = entrance
        self.tempo = tempo
        self.appearDelay = appearDelay
    }

    /// The wait before the first entrance: a random `appearDelay`, scaled
    /// by 1/`tempo`; 0 = come out at once.
    func entranceDelay(using generator: inout some RandomNumberGenerator) -> Double {
        let range = max(appearDelay.lowerBound, 0)...max(appearDelay.upperBound, 0)
        guard range.upperBound > 0 else { return 0 }
        return Double.random(in: range, using: &generator) / max(tempo, 0.1)
    }

    /// The default style: it climbs out, at normal speed.
    public static let standard = FigureStyle()
}
