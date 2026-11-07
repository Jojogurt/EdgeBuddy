import EdgeBuddy
import SwiftUI

/// `peekingFigure()`: one card, no stage to set up — onboarding, empty
/// states.
struct SingleCardTab: View {
    @State private var done = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Nothing here yet").font(.title2.bold())
                    Text("Add your first item to get started.")
                        .foregroundStyle(.secondary)
                    Card(title: "Empty state", height: 160)
                        .peekingFigure(isWaiting: done)
                    Toggle("Hold the figure", isOn: $done)
                        .padding(.top, 24)
                }
                .padding()
                .padding(.top, 80)
            }
            .navigationTitle("Single card")
        }
    }
}
