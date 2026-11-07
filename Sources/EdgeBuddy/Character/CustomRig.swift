import SwiftUI

/// A character of the app's own on the stage: its actions sequenced by
/// `FigureSequence`, its boxes as the geometry.
enum CustomRig {
    static func character<Character: FigureCharacter>(_ character: Character) -> AnyFigureCharacter {
        // Asked once per character value, not per frame or per pick.
        let table = ActionTable(character)
        let geometry = FigureGeometry(
            top: character.box(at: .top), bottom: character.box(at: .bottom),
            leading: character.box(at: .leading), trailing: character.box(at: .trailing),
            referenceHeight: max(character.referenceHeight, 1e-3),
            supportedEdges: table.supportedEdges,
            screenEdgeSideRoom: (table.leading + table.trailing)
                .filter(\.playsAtScreenEdge).map(\.minimumRoom).min()
        )
        return AnyFigureCharacter(
            typeID: ObjectIdentifier(Character.self),
            geometry: geometry,
            actions: { edge, room, atScreenEdge in
                table[edge]
                    .filter { $0.minimumRoom <= room + 1e-9 && (!atScreenEdge || $0.playsAtScreenEdge) }
                    .map(\.name)
            },
            info: { name, edge in
                guard let action = table.action(name, at: edge) else {
                    return FigureActionInfo(travelPerBeat: nil, repeatRange: 1...1, defaultRepeats: 1)
                }
                return FigureActionInfo(
                    travelPerBeat: action.travel > 0 ? action.travel : nil,
                    repeatRange: action.repeats, defaultRepeats: action.repeats.lowerBound
                )
            },
            pinned: { name, edge in table.action(name, at: edge) == nil ? FigureActionName.rest : name },
            play: { request in
                FigurePlay(FigureSequence(character, action: table.action(request.action, at: request.edge), request: request))
            },
            frame: { play, time, edge, heading in
                guard let sequence = play.base as? FigureSequence<Character.Pose> else { return nil }
                let pose = FigureSignpost.interval("joints") { sequence.pose(at: time) }
                return FigureFrame(
                    isOut: sequence.isOut(at: time),
                    // Heading left along the top or the bottom: the mirror image.
                    isMirrored: !edge.isSide && heading < 0
                ) { context, color in
                    character.draw(pose, in: &context, color: color)
                }
            }
        )
    }

    /// A character's actions per edge.
    struct ActionTable<Pose: FigureCharacterPose>: Sendable {
        let top, bottom, leading, trailing: [FigureCharacterAction<Pose>]

        init<Character: FigureCharacter>(_ character: Character) where Character.Pose == Pose {
            top = character.actions(at: .top)
            bottom = character.actions(at: .bottom)
            leading = character.actions(at: .leading)
            trailing = character.actions(at: .trailing)
        }

        subscript(edge: FigureEdge) -> [FigureCharacterAction<Pose>] {
            switch edge {
            case .top: top
            case .bottom: bottom
            case .leading: leading
            case .trailing: trailing
            }
        }

        func action(_ name: String, at edge: FigureEdge) -> FigureCharacterAction<Pose>? {
            self[edge].first { $0.name == name }
        }

        var supportedEdges: FigureEdges {
            FigureEdges(FigureEdge.allCases.filter { !self[$0].isEmpty }.map(\.member))
        }
    }
}

/// One play of a custom character: out from behind the card (its entrance,
/// or a rise from the hidden pose), a hold, the action's beats (blended in
/// and out of the rest pose), a hold, and back (the entrance backwards) —
/// the same shape and the same randomness (`FigureVariation`) as the human
/// rig's plays. Built once per play; `pose(at:)` scans a handful of segments.
struct FigureSequence<Pose: FigureCharacterPose>: FigurePlayable {
    /// When the figure takes taps during a segment.
    enum Visibility: Sendable {
        case out, hidden
        /// Out from half-way through.
        case entering
        /// Out until half-way through.
        case leaving
    }

    enum Kind: Sendable {
        case blend(from: Pose, to: Pose, easing: FigureTimeline.Easing)
        /// `beats` beats of `motion`, played `pace` times as fast, or
        /// backwards (an exit).
        case motion(FigureMotion<Pose>, beats: Int, pace: Double, reversed: Bool)
    }

    struct Segment: Sendable {
        var start: Double
        var end: Double
        var kind: Kind
        var visibility: Visibility
    }

    let segments: [Segment]
    /// After the last segment (and with none).
    let last: Pose
    let lastVisibility: Visibility
    let fadesIn: Bool
    let relocatesAt: Double?
    let walkWindow: ClosedRange<Double>?
    let walkDistance: Double?
    let hiddenPause: Double?
    let holdTime: Double?

    /// The default entrance: a rise from hidden to rest with a small overshoot.
    static var riseDuration: Double { 0.5 }
    /// Blending from rest into an action's first pose and back, seconds.
    static var blendDuration: Double { 0.25 }

    init<Character: FigureCharacter>(
        _ character: Character, action: FigureCharacterAction<Pose>?, request: FigurePlayRequest
    ) where Character.Pose == Pose {
        let edge = request.edge
        let rest = character.restPose(at: edge)
        let variation = request.variation
        if request.reduceMotion {
            // A fixed crossfade into the rest pose, independent of tempo.
            segments = [Segment(
                start: 0, end: request.entrance != nil ? 0.2 : 0.01,
                kind: .blend(from: rest, to: rest, easing: .inOut), visibility: .out
            )]
            last = rest
            lastVisibility = .out
            fadesIn = request.entrance != nil
            relocatesAt = nil
            walkWindow = nil
            walkDistance = nil
            hiddenPause = nil
            holdTime = nil
            return
        }

        let pace = max(request.tempo * variation.tempoScale, 0.1)
        var segments: [Segment] = []
        var time = 0.0
        func add(_ seconds: Double, _ kind: Kind, _ visibility: Visibility = .out) {
            let end = time + max(seconds, 0) / pace
            segments.append(Segment(start: time, end: end, kind: kind, visibility: visibility))
            time = end
        }
        func blend(_ seconds: Double, _ from: Pose, _ to: Pose, _ easing: FigureTimeline.Easing = .inOut,
                   _ visibility: Visibility = .out) {
            add(seconds, .blend(from: from, to: to, easing: easing), visibility)
        }
        /// Standing still at `pose`, seconds as given (already random, not tempo-scaled).
        func hold(_ seconds: Double, _ pose: Pose) {
            guard seconds > 0 else { return }
            add(seconds * pace, .blend(from: pose, to: pose, easing: .inOut))
        }

        let hidden = character.hiddenPose(at: edge)
        let entrance = character.entrance(at: edge) ?? FigureMotion(duration: Self.riseDuration) { t in
            // Exact at both ends (the easing's float error would not be).
            guard t > 0 else { return hidden }
            guard t < Self.riseDuration else { return rest }
            return hidden.interpolated(to: rest, FigureTimeline.ease(t / Self.riseDuration, .out))
        }
        let comesOut = request.relocating || request.entrance != nil
        var relocation: Double?
        if request.relocating {
            // Duck from the pose shown at the edge it leaves.
            let before = request.previousEdge ?? edge
            let start = request.previousPose as? Pose ?? character.restPose(at: before)
            blend(FigureTimeline.duckDuration, start, character.hiddenPose(at: before), .in, .leaving)
            relocation = time
            blend(0.12, hidden, hidden, .inOut, .hidden)
        }
        if comesOut { add(entrance.duration, .motion(entrance, beats: 1, pace: pace, reversed: false), .entering) }
        hold(variation.holdBefore, rest)

        var walk: ClosedRange<Double>?
        var distance: Double?
        var signature: Double?
        if let action {
            let motion = action.motion
            let beats = max(variation.repeats ?? action.repeats.lowerBound, 1)
            let opening = motion.pose(at: 0), closing = motion.pose(at: motion.duration)
            if opening != rest { blend(Self.blendDuration, rest, opening) }
            let begin = time
            add(motion.duration * Double(beats), .motion(motion, beats: beats, pace: pace, reversed: false))
            let hold = min(max(action.hold ?? motion.duration / 2, 0), motion.duration)
            signature = begin + hold / pace
            if action.travel > 0, time > begin {
                walk = begin...time
                distance = action.travel * Double(beats)
            }
            if closing != rest { blend(Self.blendDuration, closing, rest) }
        }
        if variation.exit != nil {
            hold(variation.holdAfter, rest)
            add(entrance.duration, .motion(entrance, beats: 1, pace: pace, reversed: true), .leaving)
            hiddenPause = variation.hiddenPause
            last = hidden
            lastVisibility = .hidden
        } else {
            hiddenPause = nil
            last = rest
            lastVisibility = .out
        }
        self.segments = segments
        fadesIn = false
        relocatesAt = relocation
        walkWindow = walk
        walkDistance = distance
        holdTime = signature
    }

    var duration: Double { segments.last?.end ?? 0 }

    func pose(at time: Double) -> Pose {
        guard let head = segments.first else { return last }
        if time <= head.start { return Self.pose(of: head, at: head.start) }
        for segment in segments where time <= segment.end {
            return Self.pose(of: segment, at: time)
        }
        return last
    }

    private static func pose(of segment: Segment, at time: Double) -> Pose {
        let length = segment.end - segment.start
        switch segment.kind {
        case let .blend(from, to, easing):
            let u = length > 0 ? min(max((time - segment.start) / length, 0), 1) : 1
            return from.interpolated(to: to, FigureTimeline.ease(u, easing))
        case let .motion(motion, beats, pace, reversed):
            var local = min(max((time - segment.start) * pace, 0), motion.duration * Double(beats))
            if reversed { local = motion.duration * Double(beats) - local }
            guard motion.duration > 0 else { return motion.pose(at: 0) }
            // The last instant of a beat is its end pose, not the next one's start.
            let beat = min((local / motion.duration).rounded(.down), Double(beats - 1))
            return motion.pose(at: local - beat * motion.duration)
        }
    }

    /// Out far enough to tap at `time`.
    func isOut(at time: Double) -> Bool {
        guard let segment = segments.first(where: { time <= $0.end }) else { return lastVisibility == .out }
        let length = segment.end - segment.start
        let u = length > 0 ? (time - segment.start) / length : 1
        switch segment.visibility {
        case .out: return true
        case .hidden: return false
        case .entering: return u >= 0.5
        case .leaving: return u < 0.5
        }
    }

    var stillWindows: [ClosedRange<Double>] {
        guard !fadesIn else { return [] }
        var windows: [ClosedRange<Double>] = []
        for segment in segments where segment.end > segment.start {
            guard case let .blend(from, to, _) = segment.kind, from == to else { continue }
            if let last = windows.last, abs(last.upperBound - segment.start) < 1e-9 {
                windows[windows.count - 1] = last.lowerBound...segment.end
            } else {
                windows.append(segment.start...segment.end)
            }
        }
        return windows.filter { $0.upperBound - $0.lowerBound >= FigureTimeline.minimumStill }
    }

    func walkProgress(at time: Double) -> Double? {
        guard let window = walkWindow else { return nil }
        return min(max((time - window.lowerBound) / max(window.upperBound - window.lowerBound, 1e-6), 0), 1)
    }

    func opacity(at time: Double) -> Double {
        fadesIn ? min(1, max(0, time / 0.2)) : 1
    }

    func anyPose(at time: Double) -> any Sendable { pose(at: time) }

    /// Plays hold closures (the actions' motions): never equal.
    func isEqual(to other: any FigurePlayable) -> Bool { false }
}
