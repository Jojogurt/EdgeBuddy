import SwiftUI

#Preview("Stage") { FigureStagePreview() }
#Preview("Stage — dark") { FigureStagePreview().preferredColorScheme(.dark) }

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
