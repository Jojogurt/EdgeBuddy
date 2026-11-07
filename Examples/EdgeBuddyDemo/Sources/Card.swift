import SwiftUI

/// A plain rounded card — what the figure comes out from behind.
struct Card: View {
    let title: LocalizedStringKey
    var height: CGFloat = 110

    var body: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.quaternary)
            .frame(height: height)
            .overlay(alignment: .topLeading) {
                Text(title).font(.headline).padding()
            }
    }
}

/// Grouped controls on a card background.
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding()
            .background(.background.secondary, in: .rect(cornerRadius: 24))
    }
}
