import SwiftUI

/// One frame of the figure's body, ready to draw: where each joint is, in the
/// rig's grid (100 × 84 units, y pointing down; the stage scales it to the
/// view). The stage has already mirrored the points for a figure facing left.
public struct FigureSkeletonPoints: Sendable {
    /// The hip.
    public var hip: CGPoint
    /// The top of the torso (the neck).
    public var torsoTop: CGPoint
    /// The centre of the head.
    public var head: CGPoint
    /// Shoulder → elbow → hand. "L" is the far limb in profile.
    public var armL: [CGPoint]
    /// Shoulder → elbow → hand.
    public var armR: [CGPoint]
    /// Hip → knee → foot. "L" is the far limb in profile.
    public var legL: [CGPoint]
    /// Hip → knee → foot.
    public var legR: [CGPoint]
    /// Opacity the far arm and leg are drawn at (1 from the front, lower in profile).
    public var farLimbOpacity: Double
    /// 1 = facing right as designed, -1 = facing left (the points are already
    /// mirrored; use it to flip art that is not symmetric). Between the two
    /// while the figure turns.
    public var facing: Double
    /// Torso tilt in degrees, + = clockwise.
    public var lean: Double
    /// Head tilt in degrees on top of `lean`, + = clockwise.
    public var tilt: Double
    /// 0 = seen from the front, 1 = in profile (the run).
    public var profile: Double

    /// The size of the grid the points live in.
    public static let gridSize = FigureSkeleton.gridSize
    /// Line width of the default arms and legs, grid units.
    public static let limbWidth = FigureSkeleton.limbWidth
    /// Line width of the default torso, grid units.
    public static let torsoWidth = FigureSkeleton.torsoWidth
    /// Radius of the default head, grid units.
    public static let headRadius = FigureSkeleton.headRadius

    /// Points of your own — for previews and tests of a character.
    public init(
        hip: CGPoint, torsoTop: CGPoint, head: CGPoint,
        armL: [CGPoint], armR: [CGPoint], legL: [CGPoint], legR: [CGPoint],
        farLimbOpacity: Double = 1, facing: Double = 1, lean: Double = 0, tilt: Double = 0, profile: Double = 0
    ) {
        self.hip = hip
        self.torsoTop = torsoTop
        self.head = head
        self.armL = armL
        self.armR = armR
        self.legL = legL
        self.legR = legR
        self.farLimbOpacity = farLimbOpacity
        self.facing = facing
        self.lean = lean
        self.tilt = tilt
        self.profile = profile
    }

    init(_ skeleton: FigureSkeleton, joints: FigureJoints) {
        self.init(
            hip: skeleton.hip, torsoTop: skeleton.torsoTop, head: skeleton.head,
            armL: skeleton.armL, armR: skeleton.armR, legL: skeleton.legL, legR: skeleton.legR,
            farLimbOpacity: skeleton.farLimbOpacity, facing: joints.facing,
            lean: joints.lean, tilt: joints.tilt, profile: joints.profile
        )
    }
}

/// A figure of your own: how the body looks, drawn from the skeleton points
/// of one frame (`FigureAppearance.character`).
///
/// The stage keeps everything else — the motion, entrances, clipping to the
/// card's edge, mirroring, taps. A character only draws.
///
/// ```swift
/// struct Ghost: FigureCharacter {
///     func draw(_ body: FigureSkeletonPoints, in context: inout GraphicsContext, color: Color) {
///         let r = 14.0
///         context.fill(Path(ellipseIn: CGRect(x: body.hip.x - r, y: body.head.y - r,
///                                             width: 2 * r, height: body.hip.y - body.head.y + 2 * r)),
///                      with: .color(color))
///     }
/// }
/// ```
///
/// - Coordinates are the rig's grid, y down; the context is already scaled
///   and translated to it. Nothing is drawn outside the stage's box for the
///   edge, so keep the art within about the default figure's reach.
/// - `draw` runs on every frame (60–120 Hz while moving): keep it cheap —
///   no allocations of images, no resolving of large views.
/// - Layout (how much room the figure needs at an edge) and the tap area are
///   those of the default body, whatever you draw.
public protocol FigureCharacter: Sendable {
    /// Draws one frame in `color` (the figure's colour, `figureColor(_:)`).
    func draw(_ body: FigureSkeletonPoints, in context: inout GraphicsContext, color: Color)
}

/// The default figure's plain drawing — a round head, one colour — as a
/// starting point for your own. (`FigureAppearance`'s head, scales and
/// colours tune this same figure without a character.)
public struct Stickman: FigureCharacter {
    public init() {}

    public func draw(_ body: FigureSkeletonPoints, in context: inout GraphicsContext, color: Color) {
        let shading = GraphicsContext.Shading.color(color)
        let limb = StrokeStyle(lineWidth: FigureSkeletonPoints.limbWidth, lineCap: .round, lineJoin: .round)
        func line(_ points: [CGPoint]) -> Path { Path { $0.addLines(points) } }

        context.drawLayer { far in
            far.opacity = body.farLimbOpacity
            far.stroke(line(body.legL), with: shading, style: limb)
            far.stroke(line(body.armL), with: shading, style: limb)
        }
        context.stroke(line(body.legR), with: shading, style: limb)
        context.stroke(
            line([body.hip, body.torsoTop]), with: shading,
            style: StrokeStyle(lineWidth: FigureSkeletonPoints.torsoWidth, lineCap: .round)
        )
        let r = FigureSkeletonPoints.headRadius
        context.fill(
            Path(ellipseIn: CGRect(x: body.head.x - r, y: body.head.y - r, width: 2 * r, height: 2 * r)),
            with: shading
        )
        context.stroke(line(body.armR), with: shading, style: limb)
    }
}
