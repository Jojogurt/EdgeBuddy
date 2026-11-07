import EdgeBuddy
import SwiftUI

/// No `ScrollView`: the stage goes on the screen's `body` and works with
/// the whole view as its region.
struct StaticTab: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Card(title: "Header", height: 140).figureAnchor("header", edges: [.top, .bottom])
                HStack(spacing: 16) {
                    Card(title: "Left", height: 160).figureAnchor("left", edges: [.top, .leading])
                    Card(title: "Right", height: 160).figureAnchor("right", edges: [.top, .trailing])
                }
                Card(title: "Footer", height: 100).figureAnchor("footer", edges: .top)
                Spacer(minLength: 0)
            }
            .padding()
            .padding(.top, 56)
            .figureStage()
            .navigationTitle("Static")
        }
    }
}
