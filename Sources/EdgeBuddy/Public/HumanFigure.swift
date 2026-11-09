import SwiftUI

/// What ``HumanFigure``'s head is drawn as.
public enum FigureHead: Sendable {
    /// A filled circle, the default.
    case circle
    /// An SF Symbol, tinted with the head colour.
    case symbol(String)
    /// A short text — typically one emoji. Emoji keep their own colours.
    case text(String)
    /// Any image, fitted into the head's square. Use
    /// `.renderingMode(.template)` on it to tint it with the head colour.
    case image(Image)
}

/// The built-in figure: a stick figure with a skeleton, two-bone IK and the
/// whole repertoire — waves, jumping jacks, a worm walk and a handstand on
/// the top, swings and pull-ups under the bottom, flags and climbs at
/// the sides — with the climb or spring entrance of `FigureStyle`.
///
/// It is the default character. Set it with `figureCharacter(_:)` to tune
/// its look — the head, the thickness of head, limbs and torso, a colour
/// per part:
///
/// ```swift
/// .figureCharacter(HumanFigure(head: .text("🐻"), headScale: 1.4, armColor: .orange))
/// ```
///
/// The look never changes the motion, the layout (the room the figure
/// needs at an edge) or the tap area, so the sizes are clamped to a range
/// that stays inside the figure's footprint.
public struct HumanFigure: FigureCharacter {
    /// One frame of the human rig: the joint angles of the skeleton.
    public struct Pose: FigureCharacterPose {
        var joints: FigureJoints

        init(_ joints: FigureJoints) {
            self.joints = joints
        }

        /// Blends every joint angle and offset.
        public func interpolated(to other: Pose, _ t: Double) -> Pose {
            Pose(joints.interpolated(to: other.joints, t))
        }

        /// Where each joint is, in the rig's grid — to draw the pose yourself.
        public var points: FigureSkeletonPoints {
            FigureSkeletonPoints(FigureSkeleton(joints), joints: joints)
        }
    }

    /// What the head is drawn as.
    public var head: FigureHead
    /// Size of the head relative to the default, 0.6…1.5.
    public var headScale: Double {
        didSet { headScale = Self.clamp(headScale) }
    }
    /// Thickness of the arms and legs relative to the default, 0.6…1.5.
    public var limbScale: Double {
        didSet { limbScale = Self.clamp(limbScale) }
    }
    /// Thickness of the torso relative to the default, 0.6…1.5.
    public var torsoScale: Double {
        didSet { torsoScale = Self.clamp(torsoScale) }
    }
    /// Colour of the head; nil = the figure's colour (`figureColor(_:)`).
    public var headColor: Color?
    /// Colour of the torso; nil = the figure's colour.
    public var torsoColor: Color?
    /// Colour of the arms; nil = the figure's colour.
    public var armColor: Color?
    /// Colour of the legs; nil = the figure's colour.
    public var legColor: Color?
    /// true = a `symbol`, `text` or `image` head is flipped when the figure
    /// faces left; false (default) keeps it as drawn (right for text).
    public var mirrorsHead: Bool

    /// A figure; every parameter has the default look (a round head, one colour).
    public init(
        head: FigureHead = .circle, headScale: Double = 1, limbScale: Double = 1,
        torsoScale: Double = 1, headColor: Color? = nil, torsoColor: Color? = nil,
        armColor: Color? = nil, legColor: Color? = nil, mirrorsHead: Bool = false
    ) {
        self.head = head
        self.headScale = Self.clamp(headScale)
        self.limbScale = Self.clamp(limbScale)
        self.torsoScale = Self.clamp(torsoScale)
        self.headColor = headColor
        self.torsoColor = torsoColor
        self.armColor = armColor
        self.legColor = legColor
        self.mirrorsHead = mirrorsHead
    }

    static let scaleRange = 0.6...1.5

    private static func clamp(_ value: Double) -> Double {
        value.isFinite ? min(max(value, scaleRange.lowerBound), scaleRange.upperBound) : 1
    }

    public var referenceHeight: CGFloat { FigureGeometry.human.referenceHeight }

    public func box(at edge: FigureEdge) -> FigureCharacterBox {
        FigureGeometry.human.box(edge)
    }

    /// The repertoire at `edge`, each action as one whole play from the rest
    /// pose back to it (the stage itself plays the rig, with its random
    /// repeat counts, routes and grips).
    public func actions(at edge: FigureEdge) -> [FigureCharacterAction<Pose>] {
        FigureRepertoire.actions(for: edge).map { action in
            let timeline = FigureTimeline(action: action, entrance: nil, reduceMotion: false, edge: edge)
            return FigureCharacterAction(
                action.name,
                motion: FigureMotion(duration: timeline.duration) { Pose(timeline.joints(at: $0)) },
                travel: FigureTimeline.travel(action, repeats: FigureTimeline.canvasRepeats(action)) ?? 0,
                hold: timeline.holdTime,
                playsAtScreenEdge: FigureRepertoire.screenEdgeSide.contains(action)
            )
        }
    }

    public func restPose(at edge: FigureEdge) -> Pose {
        Pose(FigureTimeline.restPose(edge))
    }

    public func hiddenPose(at edge: FigureEdge) -> Pose {
        Pose(FigureTimeline.hiddenPose(.spring, edge: edge))
    }

    /// The spring entrance at `edge` (`FigureStyle.entrance` picks the
    /// top's entrance on the stage).
    public func entrance(at edge: FigureEdge) -> FigureMotion<Pose>? {
        let timeline = FigureTimeline(
            action: .rest, entrance: .spring, reduceMotion: false, edge: edge, variation: FigureVariation(repeats: 0)
        )
        return FigureMotion(duration: timeline.duration) { Pose(timeline.joints(at: $0)) }
    }

    public func draw(_ pose: Pose, in context: inout GraphicsContext, color: Color) {
        HumanDrawing.draw(pose.joints, figure: self, in: &context, color: color)
    }
}

/// One frame of the human figure's body, ready to draw: where each joint
/// is, in the rig's grid (100 × 84 units, y pointing down). The points are
/// already mirrored for a figure facing left (`HumanFigure.Pose.points`).
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

    /// Points of your own — for previews and tests.
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
