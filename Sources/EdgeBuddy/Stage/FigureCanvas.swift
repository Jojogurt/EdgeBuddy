import SwiftUI

/// One frame of a character: `viewBox` (a part of the character's space,
/// y down) scaled to the view's height, then `draw` in it. Shared with
/// `RunningFigure`.
struct FigureCanvas: View {
    let color: Color
    /// The part of the character's space the view shows.
    let viewBox: CGRect
    let draw: (inout GraphicsContext, Color) -> Void

    var body: some View {
        Canvas { context, size in
            let scale = size.height / viewBox.height
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -viewBox.minX, y: -viewBox.minY)
            draw(&context, color)
        }
    }
}
