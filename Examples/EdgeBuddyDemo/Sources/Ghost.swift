import EdgeBuddy
import SwiftUI

/// A custom figure: a ghost that follows the skeleton's head and hip.
struct Ghost: FigureCharacter {
    func draw(_ body: FigureSkeletonPoints, in context: inout GraphicsContext, color: Color) {
        let width = 26.0
        let top = body.head.y - 12, bottom = body.hip.y + 14
        let x = (body.head.x + body.hip.x) / 2
        var path = Path()
        path.move(to: CGPoint(x: x - width / 2, y: bottom))
        path.addLine(to: CGPoint(x: x - width / 2, y: top + width / 2))
        path.addArc(center: CGPoint(x: x, y: top + width / 2), radius: width / 2,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: x + width / 2, y: bottom))
        for i in 0..<3 {   // wavy hem
            let step = width / 3
            path.addQuadCurve(
                to: CGPoint(x: x + width / 2 - step * Double(i + 1), y: bottom),
                control: CGPoint(x: x + width / 2 - step * (Double(i) + 0.5), y: bottom + (i % 2 == 0 ? 6 : -6))
            )
        }
        context.fill(path, with: .color(color))
        for dx in [-4.0, 4.0] {
            let eye = CGRect(x: x + dx - 2 + body.facing * 2, y: top + width / 2 - 2, width: 4, height: 5)
            context.fill(Path(ellipseIn: eye), with: .color(.white))
        }
    }
}
