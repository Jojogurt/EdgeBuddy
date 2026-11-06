import EdgeBuddy
import SwiftUI

/// A one-file demo of EdgeBuddy: a scrolling screen of cards with one
/// figure, a single card with its own figure, and a running loader.
@main
struct EdgeBuddyDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoScreen()
        }
    }
}

struct DemoScreen: View {
    @State private var color = Color.green
    @State private var height: CGFloat = 56
    @State private var haptics = true
    @State private var celebrating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Today", height: 200)
                        .figureAnchor("today", edges: .all)

                    Text("The figure stands on the card's top edge, hangs under its bottom edge and peeks at the sides.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Card(title: "This week", height: 140)
                        .figureAnchor("week", edges: [.top, .bottom])

                    settings

                    ForEach(1...5, id: \.self) { index in
                        Card(title: "Card \(index)", height: 110)
                            .figureAnchor(index, edges: [.top, .trailing])
                    }

                    Card(title: "Loading", height: 110)
                        .overlay(alignment: .trailing) { loader.padding() }
                }
                .padding()
                .padding(.top, height)
            }
            // One figure for the whole screen; it waits while "celebrating".
            .figureStage(isWaiting: celebrating)
            .figureColor(color)
            .figureHeight(height)
            .figureHaptics(haptics)
            .navigationTitle("EdgeBuddy")
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            ColorPicker("Colour", selection: $color)
            Stepper("Height: \(Int(height)) pt", value: $height, in: 32...96, step: 8)
            Toggle("Haptics", isOn: $haptics)
            Toggle("Hold the stage", isOn: $celebrating)
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 24))
    }

    private var loader: some View {
        TimelineView(.animation) { context in
            RunningFigure(
                phase: context.date.timeIntervalSinceReferenceDate / RunningFigure.cycleDuration,
                color: color
            )
        }
        .frame(width: 54, height: 56)
        .accessibilityLabel("Loading")
    }
}

private struct Card: View {
    let title: LocalizedStringKey
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.quaternary)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                Text(title).font(.headline).padding()
            }
    }
}
