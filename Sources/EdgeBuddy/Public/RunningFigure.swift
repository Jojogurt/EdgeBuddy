import SwiftUI

/// The figure seen from the side, running in place — one frame of the run
/// cycle at `phase`. Drive `phase` yourself (for example from a
/// `TimelineView`) to build a loading indicator:
///
/// ```swift
/// TimelineView(.animation) { context in
///     let seconds = context.date.timeIntervalSinceReferenceDate
///     RunningFigure(phase: seconds / RunningFigure.cycleDuration, color: .green)
/// }
/// .frame(width: 54, height: 56)
/// ```
///
/// Decoration only: it has no accessibility element of its own — give the
/// container a label such as "Loading".
public struct RunningFigure: View {
    /// Length of one full run cycle (two steps) at normal speed, seconds.
    nonisolated public static let cycleDuration: Double = FigureJoints.runCycle

    /// The part of the rig's grid that frames the whole running body, feet
    /// included (100 × 104 units, y from 12); the default `viewBox`.
    nonisolated public static let bodyBox = CGRect(x: 0, y: 12, width: 100, height: 104)

    private let phase: Double
    private let color: Color
    private let viewBox: CGRect
    private let figure: HumanFigure

    /// One frame of the run.
    ///
    /// - Parameters:
    ///   - phase: position in the run, in cycles: 0…1 is one full stride
    ///     (both legs); the motion repeats every whole number.
    ///   - color: the figure's colour.
    ///   - viewBox: the part of the rig's grid to show, scaled to the view's
    ///     height. Defaults to `bodyBox`; its aspect ratio is the view's.
    ///   - figure: the figure's look (head, thickness, colours per part);
    ///     the default round head and one colour.
    public init(
        phase: Double, color: Color, viewBox: CGRect = RunningFigure.bodyBox,
        figure: HumanFigure = HumanFigure()
    ) {
        self.figure = figure
        self.phase = phase
        self.color = color
        self.viewBox = viewBox
    }

    public var body: some View {
        FigureCanvas(color: color, viewBox: viewBox) { [figure, phase] context, color in
            HumanDrawing.draw(.run(phase: phase), figure: figure, in: &context, color: color)
        }
    }
}
