import EdgeBuddy
import SwiftUI

/// A character of its own: a ghost with no arms or legs — its own pose (a
/// body that floats, sways, stretches and ripples), its own actions on the
/// top and at the sides (none under the bottom) and its own drawing.
struct Ghost: FigureCharacter {
    /// One frame of the ghost, in its units (64 = `figureHeight`).
    struct Pose: FigureCharacterPose {
        /// Centre of the body.
        var x: Double
        var y: Double
        /// Tilt around the centre, degrees, + = clockwise.
        var tilt: Double = 0
        /// 1 = as drawn; > 1 taller and narrower.
        var stretch: Double = 1
        /// The hem's ripple, -1…1.
        var ripple: Double = 1
        /// Where the eyes look, -1 (left) … 1 (right).
        var look: Double = 0
        /// 0 = mouth closed … 1 = a wide "boo".
        var mouth: Double = 0

        func interpolated(to other: Pose, _ t: Double) -> Pose {
            func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
            return Pose(
                x: mix(x, other.x), y: mix(y, other.y), tilt: mix(tilt, other.tilt),
                stretch: mix(stretch, other.stretch), ripple: mix(ripple, other.ripple),
                look: mix(look, other.look), mouth: mix(mouth, other.mouth)
            )
        }
    }

    private static let topRest = Pose(x: 32, y: 40)
    /// Half out from behind the card's side: it fits a 16 pt gutter.
    private static let sideRest = Pose(x: 10, y: 36, tilt: -6, look: 0.6)

    func box(at edge: FigureEdge) -> FigureCharacterBox {
        switch edge {
        // Above the card, its edge at the box's bottom.
        case .top: FigureCharacterBox(CGRect(x: 0, y: 0, width: 64, height: 64), edge: 64)
        case .bottom: FigureCharacterBox(CGRect(x: 0, y: 0, width: 64, height: 64), edge: 0)
        // Beside the card, its edge at the box's left side.
        case .leading, .trailing: FigureCharacterBox(CGRect(x: 0, y: 0, width: 48, height: 72), edge: 0)
        }
    }

    func restPose(at edge: FigureEdge) -> Pose {
        edge == .top ? Self.topRest : Self.sideRest
    }

    func hiddenPose(at edge: FigureEdge) -> Pose {
        switch edge {
        case .top, .bottom: Self.topRest.with { $0.y += 66; $0.stretch = 0.8 }
        case .leading, .trailing: Self.sideRest.with { $0.x -= 30; $0.tilt = -12 }
        }
    }

    func actions(at edge: FigureEdge) -> [FigureCharacterAction<Pose>] {
        switch edge {
        case .top:
            let rest = Self.topRest
            return [
                FigureCharacterAction("float", motion: Self.beat(1.4, rest) { u, pose in
                    pose.y -= 6 * (1 - cos(2 * .pi * u)) / 2
                    pose.ripple = cos(4 * .pi * u)
                    pose.look = 0.7 * sin(2 * .pi * u)
                }, repeats: 2...3),
                FigureCharacterAction("sway", motion: Self.beat(1.2, rest) { u, pose in
                    pose.tilt = 12 * sin(2 * .pi * u)
                    pose.x += 4 * sin(2 * .pi * u)
                    pose.look = sin(2 * .pi * u)
                    pose.ripple = cos(2 * .pi * u)
                }, repeats: 2...3),
                FigureCharacterAction("boo", motion: Self.beat(1.6, rest) { u, pose in
                    let up = sin(.pi * u)
                    pose.y -= 10 * up
                    pose.stretch = 1 + 0.25 * up
                    pose.mouth = up
                    pose.ripple = cos(6 * .pi * u)
                }, repeats: 1...2, hold: 0.8),
                FigureCharacterAction("drift", motion: Self.beat(0.9, rest) { u, pose in
                    pose.tilt = 10 * sin(.pi * u)
                    pose.y -= 3 * sin(2 * .pi * u)
                    pose.ripple = cos(2 * .pi * u)
                    pose.look = sin(.pi * u)
                }, repeats: 2...4, travel: 22),
            ]
        case .bottom:
            // Never under a card.
            return []
        case .leading, .trailing:
            let rest = Self.sideRest
            return [
                FigureCharacterAction("peek", motion: Self.beat(1.8, rest) { u, pose in
                    let out = sin(.pi * u)
                    pose.x += 10 * out
                    pose.tilt = -6 + 16 * out
                    pose.look = 0.6 + 0.4 * out
                    pose.ripple = cos(4 * .pi * u)
                }, repeats: 1...2, hold: 0.9),
                FigureCharacterAction("boo", motion: Self.beat(1.4, rest) { u, pose in
                    let up = sin(.pi * u)
                    pose.x += 8 * up
                    pose.stretch = 1 + 0.2 * up
                    pose.mouth = up
                    pose.tilt = -6 + 6 * up
                }, hold: 0.7),
                FigureCharacterAction("haunt", motion: Self.beat(1.0, rest) { u, pose in
                    pose.tilt = -6 + 6 * sin(2 * .pi * u)
                    pose.ripple = cos(2 * .pi * u)
                }, repeats: 2...3, travel: 24),
            ]
        }
    }

    /// One beat starting and ending exactly at `rest`: `change` shapes it
    /// at `u` (0…1).
    private static func beat(
        _ duration: Double, _ rest: Pose, _ change: @escaping @Sendable (Double, inout Pose) -> Void
    ) -> FigureMotion<Pose> {
        FigureMotion(duration: duration) { time in
            let u = time / duration
            guard u > 0, u < 1 else { return rest }
            var pose = rest
            change(u, &pose)
            return pose
        }
    }

    func draw(_ pose: Pose, in context: inout GraphicsContext, color: Color) {
        let width = 30 / pose.stretch.squareRoot()
        let height = 38 * pose.stretch
        var layer = context
        layer.translateBy(x: pose.x, y: pose.y)
        layer.rotate(by: .degrees(pose.tilt))

        // A dome, straight sides and a rippling hem of three scallops.
        let top = -height / 2, bottom = height / 2, half = width / 2
        var body = Path()
        body.move(to: CGPoint(x: -half, y: bottom))
        body.addLine(to: CGPoint(x: -half, y: top + half))
        body.addArc(center: CGPoint(x: 0, y: top + half), radius: half,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        body.addLine(to: CGPoint(x: half, y: bottom))
        let step = width / 3
        for i in 0..<3 {
            let dip = (i % 2 == 0 ? 1.0 : -1.0) * 4 * pose.ripple
            body.addQuadCurve(
                to: CGPoint(x: half - step * Double(i + 1), y: bottom),
                control: CGPoint(x: half - step * (Double(i) + 0.5), y: bottom + dip)
            )
        }
        body.closeSubpath()
        layer.fill(body, with: .color(color))

        // Eyes with pupils that look around, and a mouth for the "boo".
        let eyeY = top + half - 1
        for dx in [-5.5, 5.5] {
            layer.fill(Path(ellipseIn: CGRect(x: dx - 3, y: eyeY - 4, width: 6, height: 8)), with: .color(.white))
            let pupil = CGRect(x: dx - 1.6 + 1.4 * pose.look, y: eyeY - 1.6, width: 3.2, height: 3.6)
            layer.fill(Path(ellipseIn: pupil), with: .color(.black.opacity(0.8)))
        }
        if pose.mouth > 0.02 {
            let mouth = CGRect(x: -2.5 * (1 + pose.mouth), y: eyeY + 7, width: 5 * (1 + pose.mouth), height: 7 * pose.mouth)
            layer.fill(Path(ellipseIn: mouth), with: .color(.black.opacity(0.75)))
        }
    }
}

private extension Ghost.Pose {
    func with(_ change: (inout Self) -> Void) -> Self {
        var copy = self
        change(&copy)
        return copy
    }
}
