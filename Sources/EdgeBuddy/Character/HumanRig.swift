import SwiftUI

/// The human figure on the stage: the rig (`FigureTimeline`,
/// `FigureEdgePoses`, `FigureRepertoire`) behind the type-erased character.
enum HumanRig {
    /// `figure` on the stage.
    static func character(_ figure: HumanFigure = HumanFigure()) -> AnyFigureCharacter {
        AnyFigureCharacter(
            typeID: ObjectIdentifier(HumanFigure.self),
            geometry: .human,
            actions: { edge, room, atScreenEdge in
                FigureRepertoire.actions(for: edge, room: room, atScreenEdge: atScreenEdge).map(\.name)
            },
            info: { name, _ in info(FigureAction(name: name) ?? .rest) },
            pinned: { name, edge in (FigurePose(name: name)?.action(at: edge) ?? .rest).name },
            play: { FigurePlay(timeline($0)) },
            frame: { play, time, edge, heading in
                guard let timeline = play.base as? FigureTimeline else { return nil }
                let pose = joints(timeline, at: time, edge: edge, heading: heading)
                return FigureFrame(isOut: isOut(pose, at: edge)) { context, color in
                    HumanDrawing.draw(pose, figure: figure, in: &context, color: color)
                }
            }
        )
    }

    static func info(_ action: FigureAction) -> FigureActionInfo {
        FigureActionInfo(
            travelPerBeat: FigureTimeline.travel(action, repeats: 1),
            repeatRange: FigureVariation.repeatRange(action),
            defaultRepeats: FigureTimeline.canvasRepeats(action)
        )
    }

    /// The rig's timeline for `request`. Mid-climb or mid-flag at a side it
    /// leaves from the pose shown (`FigureEdgePoses.route(leaving:)`).
    static func timeline(_ request: FigurePlayRequest) -> FigureTimeline {
        let before = request.previousEdge ?? request.edge
        return FigureTimeline(
            action: FigureAction(name: request.action) ?? .rest, entrance: request.entrance,
            reduceMotion: request.reduceMotion, edge: request.edge, relocating: request.relocating,
            from: request.previousEdge, pose: before.isSide ? request.previousPose as? FigureJoints : nil,
            tempo: request.tempo, variation: request.variation
        )
    }

    /// The pose at `elapsed`; on the top it leans a little into the walk,
    /// and heading left (`heading` < 0) the profile is mirrored (the turn
    /// blends with `profile`).
    static func joints(_ timeline: FigureTimeline, at elapsed: Double, edge: FigureEdge, heading: Double) -> FigureJoints {
        var joints = FigureSignpost.interval("joints") { timeline.joints(at: elapsed) }
        guard edge == .top else { return joints }
        if let progress = timeline.walkProgress(at: elapsed), heading != 0, joints.profile == 0 {
            // Fraction grows to the right; lean + = right.
            joints.lean += (heading > 0 ? 5 : -5) * sin(progress * .pi)
        }
        if heading < 0 {
            // Mirrored around the box's middle, not the hip: poses off the
            // middle (the worm) stay inside the box.
            joints.facing = 1 - 2 * joints.profile
            joints.x *= joints.facing
        }
        return joints
    }

    /// The figure is out from behind its card (or edge) far enough to tap.
    static func isOut(_ pose: FigureJoints, at edge: FigureEdge) -> Bool {
        switch edge {
        case .top: pose.y < 40
        case .bottom: pose.y > -40
        case .leading, .trailing: pose.x > 44
        }
    }
}

/// Draws one frame of `HumanFigure` in the rig's grid: far limbs (faded in
/// profile), torso, head, near limbs.
enum HumanDrawing {
    static func draw(_ joints: FigureJoints, figure: HumanFigure, in context: inout GraphicsContext, color: Color) {
        let skeleton = FigureSkeleton(joints)
        func shading(_ part: Color?) -> GraphicsContext.Shading { .color(part ?? color) }
        let limb = StrokeStyle(
            lineWidth: FigureSkeleton.limbWidth * figure.limbScale, lineCap: .round, lineJoin: .round
        )
        func polyline(_ points: [CGPoint]) -> Path {
            Path { $0.addLines(points) }
        }

        // One layer, so the far arm and leg fade as a whole where they cross.
        context.drawLayer { far in
            far.opacity = skeleton.farLimbOpacity
            far.stroke(polyline(skeleton.legL), with: shading(figure.legColor), style: limb)
            far.stroke(polyline(skeleton.armL), with: shading(figure.armColor), style: limb)
        }
        context.stroke(polyline(skeleton.legR), with: shading(figure.legColor), style: limb)
        context.stroke(
            polyline([skeleton.hip, skeleton.torsoTop]), with: shading(figure.torsoColor),
            style: StrokeStyle(lineWidth: FigureSkeleton.torsoWidth * figure.torsoScale, lineCap: .round)
        )
        drawHead(figure, joints: joints, at: skeleton.head, in: &context, color: color)
        context.stroke(polyline(skeleton.armR), with: shading(figure.armColor), style: limb)
    }

    private static func drawHead(
        _ figure: HumanFigure, joints: FigureJoints, at head: CGPoint,
        in context: inout GraphicsContext, color: Color
    ) {
        let tint = figure.headColor ?? color
        if case .circle = figure.head {
            let r = FigureSkeleton.headRadius * figure.headScale
            context.fill(
                Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r, width: 2 * r, height: 2 * r)),
                with: .color(tint)
            )
            return
        }
        let side = 2 * FigureSkeleton.headRadius * figure.headScale
        // Tilts with the body (+ = clockwise); a left-facing figure leans the other way.
        let facing = joints.facing
        var layer = context
        layer.translateBy(x: head.x, y: head.y)
        layer.rotate(by: .degrees((joints.lean + joints.tilt) * (facing < 0 ? -1 : 1)))
        if figure.mirrorsHead { layer.scaleBy(x: facing, y: 1) }
        switch figure.head {
        case .circle:
            break
        case .symbol(let name):
            var image = layer.resolve(Image(systemName: name))
            image.shading = .color(tint)
            layer.draw(image, in: fitted(image.size, side: side))
        case .text(let text):
            let resolved = layer.resolve(Text(text).font(.system(size: side * 0.85)).foregroundStyle(tint))
            let size = resolved.measure(in: CGSize(width: CGFloat.infinity, height: .infinity))
            // Shrinks to fit the head's square, down to 0.3 of the size.
            let fit = min(1, side / max(size.width, 1), side / max(size.height, 1))
            layer.scaleBy(x: max(fit, 0.3), y: max(fit, 0.3))
            layer.draw(resolved, at: .zero, anchor: .center)
        case .image(let image):
            var resolved = layer.resolve(image)
            resolved.shading = .color(tint)
            layer.draw(resolved, in: fitted(resolved.size, side: side))
        }
    }

    /// A `size` scaled to fit a square `side` wide, centred on the origin.
    private static func fitted(_ size: CGSize, side: CGFloat) -> CGRect {
        let scale = side / max(size.width, size.height, 1e-6)
        let width = size.width * scale, height = size.height * scale
        return CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
    }
}
