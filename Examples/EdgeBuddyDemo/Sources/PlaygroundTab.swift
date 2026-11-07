import EdgeBuddy
import SwiftUI

/// Every setting of the stage and the figure, live. One stage on the
/// `ScrollView`, cards marked with `figureAnchor`.
struct PlaygroundTab: View {
    private enum Delay: String, CaseIterable {
        case none = "None", standard = "Default", long = "Long"

        var range: ClosedRange<Double> {
            switch self {
            case .none: 0...0
            case .standard: FigureStyle.defaultAppearDelay
            case .long: 4...6
            }
        }
    }

    /// Three looks of the built-in `HumanFigure`, and a character of its own.
    private enum Head: String, CaseIterable {
        case circle = "Circle", bear = "🐻", star = "Star", ghost = "Ghost"

        /// The human with this head.
        var human: HumanFigure {
            switch self {
            case .circle, .ghost: HumanFigure()
            case .bear: HumanFigure(head: .text("🐻"), headScale: 1.5)
            case .star: HumanFigure(head: .symbol("star.fill"), headScale: 1.5)
            }
        }

        var character: any FigureCharacter {
            self == .ghost ? Ghost() : human
        }
    }

    /// Launch with `-EdgeBuddyHead Ghost` (or 🐻, Star) to start with another figure.
    @State private var head = Head(rawValue: UserDefaults.standard.string(forKey: "EdgeBuddyHead") ?? "") ?? .circle
    @State private var color = Color.green
    @State private var height: CGFloat = 56
    @State private var opacity = 1.0
    @State private var tempo = 1.0
    @State private var entrance = FigureEntrance.climb
    @State private var delay = Delay.standard
    @State private var haptics = true
    @State private var waiting = false
    @State private var loops = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Today", height: 200)
                        .figureAnchor("today", edges: .all)
                    Text("The figure stands on a card's top edge, hangs under its bottom edge and peeks at the sides.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Card(title: "This week", height: 140)
                        .figureAnchor("week", edges: [.top, .bottom])

                    settings

                    ForEach(1...5, id: \.self) { index in
                        Card(title: "Card \(index)")
                            .figureAnchor(index, edges: [.top, .trailing])
                    }
                    Card(title: "Loading")
                        .overlay(alignment: .trailing) { loader.padding() }
                }
                .padding()
                .padding(.top, height)
            }
            .figureStage(
                style: FigureStyle(entrance: entrance, tempo: tempo, appearDelay: delay.range),
                isWaiting: waiting,
                loops: loops
            )
            .figureColor(color)
            .figureCharacter(head.character)
            .figureOpacity(opacity)
            .figureHeight(height)
            .figureHaptics(haptics)
            .navigationTitle("Playground")
        }
    }

    private var settings: some View {
        Panel {
            ColorPicker("Colour", selection: $color)
            Stepper("Height: \(Int(height)) pt", value: $height, in: 32...96, step: 8)
            LabeledContent("Opacity") { Slider(value: $opacity, in: 0.2...1) }
            LabeledContent("Tempo \(tempo.formatted(.number.precision(.fractionLength(1))))×") {
                Slider(value: $tempo, in: 0.5...2)
            }
            Picker("Head", selection: $head) {
                ForEach(Head.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Entrance", selection: $entrance) {
                Text("Climb").tag(FigureEntrance.climb)
                Text("Spring").tag(FigureEntrance.spring)
            }
            Picker("Appear delay", selection: $delay) {
                ForEach(Delay.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Toggle("Loops", isOn: $loops)
            Toggle("Haptics", isOn: $haptics)
            Toggle("Hold the stage (isWaiting)", isOn: $waiting)
        }
        .pickerStyle(.segmented)
    }

    private var loader: some View {
        TimelineView(.animation) { context in
            RunningFigure(
                phase: context.date.timeIntervalSinceReferenceDate / RunningFigure.cycleDuration,
                color: color, figure: head.human
            )
        }
        .frame(width: 54, height: 56)
        .accessibilityLabel("Loading")
    }
}
