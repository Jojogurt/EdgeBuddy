import SwiftUI

/// One frame of the rig in a single colour: far limbs (faded in profile),
/// torso, head, near limbs. Shared with `RunningFigure`.
struct FigureCanvas: View {
    let joints: FigureJoints
    let color: Color
    /// The part of the rig's grid the view shows (`RunningFigure` frames the
    /// whole body, feet included: canvas `S_loadery`, viewBox 0 12 100 104).
    var viewBox = CGRect(origin: .zero, size: FigureSkeleton.gridSize)

    var body: some View {
        Canvas { context, size in
            let scale = size.height / viewBox.height
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -viewBox.minX, y: -viewBox.minY)
            let skeleton = FigureSkeleton(joints)
            let shading = GraphicsContext.Shading.color(color)
            let limb = StrokeStyle(
                lineWidth: FigureSkeleton.limbWidth, lineCap: .round, lineJoin: .round
            )

            func polyline(_ points: [CGPoint]) -> Path {
                Path { $0.addLines(points) }
            }

            // One layer, so the far arm and leg fade as a whole where they cross.
            context.drawLayer { far in
                far.opacity = skeleton.farLimbOpacity
                far.stroke(polyline(skeleton.legL), with: shading, style: limb)
                far.stroke(polyline(skeleton.armL), with: shading, style: limb)
            }
            context.stroke(polyline(skeleton.legR), with: shading, style: limb)
            context.stroke(
                polyline([skeleton.hip, skeleton.torsoTop]), with: shading,
                style: StrokeStyle(lineWidth: FigureSkeleton.torsoWidth, lineCap: .round)
            )
            let r = FigureSkeleton.headRadius
            context.fill(
                Path(ellipseIn: CGRect(x: skeleton.head.x - r, y: skeleton.head.y - r, width: 2 * r, height: 2 * r)),
                with: shading
            )
            context.stroke(polyline(skeleton.armR), with: shading, style: limb)
        }
    }
}

