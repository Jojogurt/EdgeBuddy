import SwiftUI

/// One frame of the rig in a single colour: far limbs (faded in profile),
/// torso, head, near limbs. Shared with `RunningFigure`.
struct FigureCanvas: View {
    let joints: FigureJoints
    let color: Color
    var appearance = FigureAppearance.standard
    /// The part of the rig's grid the view shows (`RunningFigure` frames the
    /// whole body, feet included: canvas `S_loadery`, viewBox 0 12 100 104).
    var viewBox = CGRect(origin: .zero, size: FigureSkeleton.gridSize)

    private var headSide: CGFloat { 2 * FigureSkeleton.headRadius * appearance.headScale }

    var body: some View {
        Canvas { context, size in
            let scale = size.height / viewBox.height
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -viewBox.minX, y: -viewBox.minY)
            let skeleton = FigureSkeleton(joints)
            if let character = appearance.character {
                character.draw(FigureSkeletonPoints(skeleton, joints: joints), in: &context, color: color)
                return
            }
            func shading(_ part: Color?) -> GraphicsContext.Shading { .color(part ?? color) }
            let limb = StrokeStyle(
                lineWidth: FigureSkeleton.limbWidth * appearance.limbScale, lineCap: .round, lineJoin: .round
            )

            func polyline(_ points: [CGPoint]) -> Path {
                Path { $0.addLines(points) }
            }

            // One layer, so the far arm and leg fade as a whole where they cross.
            context.drawLayer { far in
                far.opacity = skeleton.farLimbOpacity
                far.stroke(polyline(skeleton.legL), with: shading(appearance.legColor), style: limb)
                far.stroke(polyline(skeleton.armL), with: shading(appearance.armColor), style: limb)
            }
            context.stroke(polyline(skeleton.legR), with: shading(appearance.legColor), style: limb)
            context.stroke(
                polyline([skeleton.hip, skeleton.torsoTop]), with: shading(appearance.torsoColor),
                style: StrokeStyle(lineWidth: FigureSkeleton.torsoWidth * appearance.torsoScale, lineCap: .round)
            )
            drawHead(in: &context, at: skeleton.head)
            context.stroke(polyline(skeleton.armR), with: shading(appearance.armColor), style: limb)
        }
        symbols: {
            headSymbol.tag(Self.headTag)
        }
    }

    private static let headTag = 0

    /// The custom head as a view; empty for the circle.
    @ViewBuilder private var headSymbol: some View {
        let tint = appearance.headColor ?? color
        switch appearance.head {
        case .circle:
            EmptyView()
        case .symbol(let name):
            Image(systemName: name).resizable().scaledToFit()
                .frame(width: headSide, height: headSide).foregroundStyle(tint)
        case .text(let text):
            Text(text).font(.system(size: headSide * 0.85)).minimumScaleFactor(0.3)
                .frame(width: headSide, height: headSide).foregroundStyle(tint)
        case .image(let image):
            image.resizable().scaledToFit()
                .frame(width: headSide, height: headSide).foregroundStyle(tint)
        }
    }

    private func drawHead(in context: inout GraphicsContext, at head: CGPoint) {
        if case .circle = appearance.head {
            let r = FigureSkeleton.headRadius * appearance.headScale
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r, width: 2 * r, height: 2 * r)),
                with: .color(appearance.headColor ?? color)
            )
            return
        }
        guard let symbol = context.resolveSymbol(id: Self.headTag) else { return }
        // Tilts with the body (+ = clockwise); a left-facing figure leans the other way.
        let facing = joints.facing
        var layer = context
        layer.translateBy(x: head.x, y: head.y)
        layer.rotate(by: .degrees((joints.lean + joints.tilt) * (facing < 0 ? -1 : 1)))
        if appearance.mirrorsHead { layer.scaleBy(x: facing, y: 1) }
        layer.draw(symbol, at: .zero)
    }
}
