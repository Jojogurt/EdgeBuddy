import EdgeBuddy
import SwiftUI

/// `figurePinned`: a deterministic, still figure — for screenshots, previews
/// and snapshot tests. The stage sits on the whole screen (cards + controls).
struct PinningTab: View {
    private let anchors = ["hero", "stats", "list"]

    @State private var anchor = "hero"
    @State private var edge = FigureEdges.top
    @State private var pose = FigurePose.wave
    @State private var spot = 0.5
    @State private var animated = true
    @State private var pinned = true

    private var pin: FigurePin? {
        pinned ? FigurePin(anchor: anchor, edge: edge, pose: pose, spot: spot, animated: animated) : nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 16) {
                        Card(title: "hero", height: 180).figureAnchor("hero", edges: .all)
                        Card(title: "stats", height: 140).figureAnchor("stats", edges: .all)
                        Card(title: "list", height: 140).figureAnchor("list", edges: .all)
                    }
                    .padding(.horizontal, 48)
                    .padding(.top, 72)
                }
                controls
            }
            .figureStage()
            .figurePinned(pin)
            .navigationTitle("Pinning")
        }
    }

    private var controls: some View {
        Panel {
            Toggle("Pinned", isOn: $pinned)
            Picker("Anchor", selection: $anchor) {
                ForEach(anchors, id: \.self) { Text($0).tag($0) }
            }
            Picker("Edge", selection: $edge) {
                Text("Top").tag(FigureEdges.top)
                Text("Bottom").tag(FigureEdges.bottom)
                Text("Leading").tag(FigureEdges.leading)
                Text("Trailing").tag(FigureEdges.trailing)
            }
            HStack {
                Picker("Pose", selection: $pose) {
                    ForEach(FigurePose.allCases, id: \.self) { Text("\($0)".capitalized).tag($0) }
                }
                Spacer()
                Toggle("Animated", isOn: $animated).fixedSize()
            }
            LabeledContent("Spot") { Slider(value: $spot, in: 0...1) }
        }
        .pickerStyle(.menu)
        .padding([.horizontal, .bottom])
        .disabled(false)
    }
}
