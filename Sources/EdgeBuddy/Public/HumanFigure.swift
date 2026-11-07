import SwiftUI

/// The built-in figure: a stick figure with a skeleton, two-bone IK and the
/// whole repertoire — waves, jumping jacks, a worm walk and a handstand on
/// the top, swings and pull-ups under the bottom, peeks, flags and climbs at
/// the sides — with the climb or spring entrance of `FigureStyle`.
///
/// It is the default character; set it explicitly with
/// `figureCharacter(_:)` to tune its look.
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

    /// The look (until it moves into the figure's own parameters).
    var appearance: FigureAppearance

    /// The default figure.
    public init() {
        self.init(appearance: .standard)
    }

    init(appearance: FigureAppearance) {
        self.appearance = appearance
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
        HumanDrawing.draw(pose.joints, appearance: appearance, in: &context, color: color)
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
