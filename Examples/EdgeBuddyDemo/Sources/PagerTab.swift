import EdgeBuddy
import SwiftUI

/// Cards in a horizontal pager (`.paging`) nested in the screen's vertical
/// `ScrollView`, the stage on the vertical one — the layout where the figure
/// must stay on its card while the screen scrolls under the navigation bar.
/// "Sides only" keeps it on the cards' sides, so it climbs often.
struct PagerTab: View {
    /// Launch with `-EdgeBuddyPagerSides YES` to start with the sides only.
    @State private var sidesOnly = UserDefaults.standard.bool(forKey: "EdgeBuddyPagerSides")

    private var edges: FigureEdges { sidesOnly ? [.leading, .trailing] : .all }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Panel {
                        Toggle("Sides only", isOn: $sidesOnly)
                        Text("Scroll the screen while the figure climbs a card's side: it should stay on the card as the card goes under the bar.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    pager

                    ForEach(1...6, id: \.self) { index in
                        Card(title: "Below \(index)")
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .figureStage()
            .navigationTitle("Pager")
        }
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(1...3, id: \.self) { page in
                    Card(title: "Page \(page) of 3", height: 240)
                        .figureAnchor("pager-\(page)", edges: edges)
                        .padding(.horizontal, 48)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
    }
}
