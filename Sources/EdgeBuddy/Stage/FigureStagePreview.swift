import SwiftUI

#Preview("Stage") { FigureStagePreview() }
#Preview("Stage — dark") { FigureStagePreview().preferredColorScheme(.dark) }
#Preview("Pinned — flag on the hero") {
    FigureStagePreview()
        .figurePinned(FigurePin(anchor: "hero", edge: .trailing, pose: .flag, spot: 0.3, animated: false))
}
#Preview("Pinned — handstand") {
    FigureStagePreview()
        .figurePinned(FigurePin(anchor: "second", edge: .top, pose: .handstand, spot: 0.8))
}
#Preview("Pinned — single card") {
    RoundedRectangle(cornerRadius: 24)
        .fill(.quaternary)
        .frame(height: 140)
        .peekingFigure()
        .figurePinned(.singleCard(pose: .wave, spot: 0.7, animated: false))
        .padding()
        .figureColor(.green)
}

private struct FigureStagePreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                card("Hero", height: 180).figureAnchor("hero", edges: .all)
                Text(verbatim: "Content above a card — the figure stands on it").font(.footnote)
                card("Second card", height: 120).figureAnchor("second", edges: [.top, .bottom])
                card("A single card", height: 120)
                    .peekingFigure(style: FigureStyle(entrance: .spring, tempo: 1.5))
                ForEach(0..<6) { index in
                    card("Card \(index + 1)", height: 96).figureAnchor(index, edges: [.top, .trailing])
                }
            }
            .padding()
            .padding(.top, PeekingFigureMetrics.defaultHeight)
        }
        .figureStage()
        .figureColor(.green)
    }

    private func card(_ title: String, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.quaternary)
            .frame(height: height)
            .overlay(Text(verbatim: title).font(.headline))
    }
}
