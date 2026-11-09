import SwiftUI

/// The animated character of a stage (`figureStage` / `peekingFigure`): one
/// figure in a box at its current anchor's edge (above the top, under the
/// bottom, beside a side). Drawn in the character's box for that edge
/// (`FigureGeometry`), clipped there, so whatever is "behind the card" never
/// shows — also over transparent (dashed) cards.
///
/// Free of app styling: colour, idle-motion policy and the tap feedback come
/// in from the stage.
struct PeekingFigureView: View {
    /// Marked views in the stage's space, in layout order.
    let anchors: [FigureAnchorFrame]
    /// Visible area of the whole stage, in its space; nil = unbounded (a single
    /// card). Each anchor may narrow it (`FigureAnchorFrame.viewport`: the
    /// scroll view it sits in, between its bars).
    let viewport: CGRect?
    var isScrolling = false
    var style = FigureStyle.standard
    var isWaiting = false
    var loops = false
    var color: Color
    /// Who plays: poses, actions, boxes and drawing (the human rig by default).
    var character = HumanRig.character()
    /// Sizes at the stage's figure height.
    var metrics = PeekingFigureMetrics.standard
    /// Idle motion allowed (foreground, not Low Power) — gates the loop.
    var idleMotionEnabled = true
    /// Low Power Mode is on — the stage's single source of truth (it follows
    /// the system notification); no action, only the rest pose, and no loop.
    var lowPowerMode = false
    /// Pinned to one anchor, edge and pose (`figurePinned(_:)`); nil = free.
    var pin: FigurePin?
    var onTap: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Hidden behind the card until the first play starts.
    @State private var timeline = FigurePlay.idle
    @State private var startDate: Date?
    @State private var hasPlayed = false
    /// A play is owed: it waits for a celebration to end.
    @State private var isPending = false
    @State private var playID = 0
    /// Behind the card (before the first entrance, after a looped cycle or
    /// when its anchor went away); the next play comes out again.
    @State private var isHidden = true
    /// Hidden with nowhere to come out right now (a scroll in progress or no
    /// anchor fully on screen) — a scroll stop or new anchors resume it.
    @State private var isParked = false
    /// The pose holds still — the animation clock stops (`stillWindows`).
    @State private var isStill = false
    /// Waiting out `FigureStyle.appearDelay` before the first entrance.
    @State private var isDelayingEntrance = false
    @State private var entranceDelay = 0.0
    /// Restarts the entrance-delay task.
    @State private var delayID = 0
    /// A step the timing tasks reached, handled in `onChange(of: due)`.
    @State private var due: FigureDue?
    /// Actions still owed after the one playing (`FigureStyle.actionsPerCycle`).
    @State private var chainLeft = 0
    /// The action playing ends standing because the run goes on.
    @State private var isChained = false
    /// The anchor it stands on (`anchorID`) and the one it stood on until it
    /// ducked mid-relocation (`previousAnchorID`).
    @State private var anchorID: AnyHashable?
    @State private var previousAnchorID: AnyHashable?
    /// The last action drawn — the next one differs.
    @State private var lastAction: String?
    /// Spots along the edge (`FigurePlacement`) for the current play: where
    /// it stood (`previousSpot`, until hidden mid-relocation), where it pops
    /// up (`spot`) and where a walk ends (`walkTarget`).
    @State private var spot = 1.0
    @State private var previousSpot = 1.0
    @State private var walkTarget = 1.0
    /// The anchor's edge it is at (`edge`) and the one it was at until it
    /// ducked mid-relocation (`previousEdge`).
    @State private var edge = FigureEdge.top
    @State private var previousEdge = FigureEdge.top
    /// Showing the pin (`FigurePinnedPlay`): no loop, no taps, no random picks.
    @State private var isPinned = false
    /// The pinned hold frame, seconds into `timeline`: drawn while the clock
    /// is stopped (`startDate` nil).
    @State private var frozenElapsed: Double?

    var body: some View {
        TimelineView(.animation(paused: startDate == nil || isStill || !isOnScreen)) { context in
            let elapsed = elapsed(at: context.date)
            // Behind the card with the clock stopped: nothing to compute or draw.
            let place = isHidden && startDate == nil ? (anchor: nil, edge: edge, spot: spot) : position(at: elapsed)
            if let rect = place.anchor.flatMap(rect(for:)) {
                // Only the part of the stage the anchor's scroll view shows.
                let visible = viewport(for: place.anchor)
                if let figure = character.frame(timeline, at: elapsed, edge: place.edge, heading: walkTarget - spot) {
                    let frame = figureFrame(at: place.edge, spot: place.spot, on: rect)
                    FigureCanvas(color: color, viewBox: metrics.box(for: place.edge), draw: figure.draw)
                        .opacity(timeline.opacity(at: elapsed))
                        .frame(width: frame.width, height: frame.height)
                        // Whatever is behind the card (past the box) never shows.
                        .clipped()
                        .contentShape(Rectangle())
                        // Sides are drawn at the trailing edge; leading mirrors it.
                        .scaleEffect(x: (place.edge == .leading) != figure.isMirrored ? -1 : 1, y: 1)
                        .onTapGesture { tapped() }
                        // Only the figure itself takes taps, and only once it is
                        // out — never the content it covers.
                        .allowsHitTesting(figure.isOut)
                        .position(x: frame.midX, y: frame.midY)
                        .clipShape(FigureRegionClip(rect: visible))
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear { appear() }
        .onDisappear {
            // The next appearance climbs in again.
            chainLeft = 0
            isChained = false
            isPinned = false
            frozenElapsed = nil
            startDate = nil
            hasPlayed = false
            isPending = false
            isHidden = true
            isParked = false
            isStill = false
            isDelayingEntrance = false
            anchorID = nil
            previousAnchorID = nil
        }
        .task(id: delayID) {
            // The first entrance after appearing waits a moment (cancelled
            // with the view, or restarted by the next appearance).
            guard isDelayingEntrance else { return }
            try? await Task.sleep(for: .seconds(entranceDelay))
            guard !Task.isCancelled, isDelayingEntrance else { return }
            due = .entrance(delayID)
        }
        // The timing tasks only say when a step is due; it is decided here.
        // A running task keeps the view's inputs (anchors, viewport,
        // isScrolling, isWaiting…) from when it started — deciding there came
        // out mid-scroll, on old frames, or stayed parked for good.
        .onChange(of: due) { _, step in
            guard let step else { return }
            due = nil
            handle(step)
        }
        .onChange(of: character.typeID) {
            // Another character: its plays differ, start over.
            restart()
        }
        .onChange(of: pin) {
            // Pinned, moved or unpinned: start over.
            isPinned = false
            frozenElapsed = nil
            isStill = false
            isParked = false
            isPending = false
            playID += 1
            appear()
        }
        .onChange(of: isWaiting) { _, waiting in
            if !waiting, isPending {
                isPending = false
                resume()
            }
        }
        .onChange(of: isScrolling) { _, scrolling in
            // A scroll ends a run: the action playing finishes, then it leaves.
            if scrolling { chainLeft = 0 }
            if !scrolling, isParked, !isWaiting { comeOut() }
        }
        // A hash, not an array: this expression runs on every scroll frame.
        .onChange(of: anchorSignature) {
            let hasAnchor = anchorID.map { id in anchors.contains { $0.id == id } } ?? true
            if isPinned, !hasAnchor {
                // The pinned card went away: free again until it is back.
                isPinned = false
                frozenElapsed = nil
            }
            if !isPinned, pin != nil, showPin() { return }
            guard !isPinned else { return }
            if !hasAnchor {
                // Its card went away (another segment, out of a lazy stack):
                // start over from behind another one, after the same wait
                // as a fresh appearance — the new content settles first.
                isStill = false
                isParked = false
                isPending = false
                playID += 1
                appear()
            } else if isParked, !isWaiting {
                comeOut()
            }
        }
        .onChange(of: viewportSignature) {
            // Laid out for real (the first pass can be empty), or resized.
            // Not when the scroll changed it (a large title collapsing): the
            // figure stays on its card as the card goes under the bar, like
            // with any scroll — never moved to what is still visible.
            if !isScrolling { reclampSpot() }
            if !isPinned, pin != nil, showPin() { return }
            if isParked, !isWaiting, !isPinned { comeOut() }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if isPinned {
                // The pin keeps its still frame, only without (or with) the motion.
                _ = showPin()
            } else if reduced {
                // Mid-action: settle into the rest pose now, no waiting it out.
                if startDate != nil, !isHidden { play(entrance: nil, action: FigureActionName.rest) }
            } else if canLoop, hasPlayed, startDate == nil, !isWaiting {
                resume()
            }
        }
        .onChange(of: idleMotionEnabled) { _, enabled in
            // Idle motion back on (foreground, Low Power off): pick the loop up.
            if enabled, !isPinned, canLoop, hasPlayed, startDate == nil, !isWaiting { resume() }
        }
        .task(id: playID) {
            guard let start = startDate else { return }
            let played = timeline
            let id = playID
            if isPinned, let hold = frozenElapsed {
                // Pinned: play up to the hold frame and stop the clock there.
                guard await sleep(until: start + hold) else { return }
                startDate = nil
                return
            }
            // Stop the clock while the pose holds still.
            for window in played.stillWindows {
                guard await sleep(until: start + window.lowerBound) else { return }
                isStill = true
                guard await sleep(until: start + window.upperBound) else { return }
                isStill = false
            }
            guard await sleep(until: start + played.duration) else { return }
            startDate = nil
            guard let pause = played.hiddenPause else {
                due = .playEnded(id)
                return
            }
            // Looped cycle: behind the card now — wait, then come out elsewhere.
            isHidden = true
            try? await Task.sleep(for: .seconds(pause))
            guard !Task.isCancelled else { return }
            due = .pauseEnded(id)
        }
    }

    /// A step a timing task reached, with the view's current inputs.
    private func handle(_ step: FigureDue) {
        switch step {
        case .entrance(let id):
            guard id == delayID, isDelayingEntrance else { return }
            isDelayingEntrance = false
            enter()
        case .playEnded(let id):
            guard id == playID else { return }
            if isChained {
                // One action of a run ended standing: the next one, or leave.
                isChained = false
                switch FigureChain.afterAction(
                    left: chainLeft, isScrolling: isScrolling, canLoop: canLoop, isWaiting: isWaiting
                ) {
                case .next:
                    chainLeft -= 1
                    play(entrance: nil, chainStep: true)
                case .leave:
                    chainLeft = 0
                    play(entrance: nil, action: FigureActionName.rest, leaving: true)
                case .stand:
                    chainLeft = 0
                    if isWaiting { isPending = true }
                }
                return
            }
            // A one-shot play (looping was off when it began) just ended: if looping
            // became allowed meanwhile (the scene turned active mid-entrance), the
            // `idleMotionEnabled` change was skipped as busy — pick the loop up now.
            if canLoop, hasPlayed, !isWaiting, !isPinned, !isHidden { resume() }
        case .pauseEnded(let id):
            guard id == playID else { return }
            if isWaiting {
                isPending = true
            } else if canLoop {
                comeOut()
            } else {
                // Idle motion went off mid-cycle: come back and stay standing.
                comeOut(action: FigureActionName.rest)
            }
        }
    }

    /// Back behind the cards, then out again as after appearing.
    private func restart() {
        isPinned = false
        frozenElapsed = nil
        isStill = false
        isParked = false
        isPending = false
        playID += 1
        appear()
    }

    /// Changes whenever the anchors' ids (or their order) do — not their
    /// frames, which move with every scroll frame.
    private var anchorSignature: Int {
        var hasher = Hasher()
        for anchor in anchors { hasher.combine(anchor.id) }
        return hasher.finalize()
    }

    /// The visible area for `anchor`: its scroll view's, else the stage's.
    private func viewport(for anchor: AnyHashable?) -> CGRect? {
        anchor.flatMap { id in anchors.first { $0.id == id }?.viewport } ?? viewport
    }

    /// Changes whenever the stage's or an anchor's visible area does (a bar
    /// grows, a scroll view resizes) — a hash, as it runs every frame.
    private var viewportSignature: Int {
        var hasher = Hasher()
        hasher.combine(viewport)
        for anchor in anchors { hasher.combine(anchor.viewport) }
        return hasher.finalize()
    }

    /// The viewport changed: keep the spots on a side inside what is visible now.
    private func reclampSpot() {
        guard !isHidden, !isPinned, let rect = anchorID.flatMap(rect(for:)), edge.isSide else { return }
        let range = spotRange(at: edge, on: rect, anchor: anchorID)
        guard let clamped = FigurePlacement.reclamped(spot: spot, walkTarget: walkTarget, into: range) else { return }
        spot = clamped.spot
        walkTarget = clamped.walkTarget
    }

    /// Sleeps until `date`; false when cancelled.
    private func sleep(until date: Date) async -> Bool {
        let seconds = date.timeIntervalSinceNow
        if seconds > 0 { try? await Task.sleep(for: .seconds(seconds)) }
        return !Task.isCancelled
    }

    /// Looping is on and allowed right now.
    private var canLoop: Bool {
        loops && idleMotionEnabled && !reduceMotion && !lowPowerMode
    }

    private func rect(for id: AnyHashable) -> CGRect? {
        anchors.first { $0.id == id }?.rect
    }

    /// The figure's box in the stage's space at `edge` of `rect`, `spot`
    /// along that edge: above the top, under the bottom, beside a side —
    /// outside the card, overlapping its edge only by the gripping hands.
    private func figureFrame(at edge: FigureEdge, spot: Double, on rect: CGRect) -> CGRect {
        let size = metrics.size(for: edge)
        switch edge {
        case .top, .bottom:
            let inset = FigurePlacement.trailingInset(
                fraction: spot, cardWidth: rect.width,
                figureWidth: size.width, margin: metrics.edgeMargin
            )
            // The box's edge line on the card's edge (the human's box ends there).
            let overlap = metrics.edgeOverlap(at: edge)
            let y = edge == .top ? rect.minY - size.height + overlap : rect.maxY - overlap
            return CGRect(x: rect.maxX - inset - size.width, y: y, width: size.width, height: size.height)
        case .leading, .trailing:
            let top = FigurePlacement.sideTop(
                fraction: spot, track: rect.minY...rect.maxY,
                boxHeight: size.height, margin: metrics.sideMargin
            )
            // Outside the card, overlapping its edge by the gripping hands.
            let overlap = metrics.sideOverlap(at: edge)
            let x = edge == .trailing ? rect.maxX - overlap : rect.minX + overlap - size.width
            return CGRect(x: x, y: top, width: size.width, height: size.height)
        }
    }

    /// Spots along `edge` of `rect` whose box is on screen right now.
    private func spotRange(at edge: FigureEdge, on rect: CGRect, anchor: AnyHashable?) -> ClosedRange<Double> {
        metrics.spotRange(at: edge, on: rect, viewport: viewport(for: anchor))
    }

    /// Some of the figure's box is in the visible area — else the clock stops.
    private var isOnScreen: Bool {
        guard viewport != nil else { return true }
        return [(anchorID, edge, spot), (previousAnchorID, previousEdge, previousSpot)]
            .contains { id, edge, spot in
                guard let visible = self.viewport(for: id), let rect = id.flatMap(rect(for:)) else { return false }
                return figureFrame(at: edge, spot: spot, on: rect).intersects(visible)
            }
    }

    private func elapsed(at date: Date) -> Double {
        if let frozenElapsed, startDate == nil { return frozenElapsed }
        if let frozenElapsed, let startDate { return min(date.timeIntervalSince(startDate), frozenElapsed) }
        return startDate.map { date.timeIntervalSince($0) } ?? (hasPlayed ? .infinity : 0)
    }

    /// Anchor, edge and spot shown at `elapsed`: the old ones until hidden
    /// mid-relocation, then the new ones, gliding to `walkTarget` while
    /// walking or climbing.
    private func position(at elapsed: Double) -> (anchor: AnyHashable?, edge: FigureEdge, spot: Double) {
        if let jump = timeline.relocatesAt, elapsed < jump { return (previousAnchorID, previousEdge, previousSpot) }
        if let progress = timeline.walkProgress(at: elapsed) {
            return (anchorID, edge, spot + (walkTarget - spot) * progress)
        }
        return (anchorID, edge, spot)
    }

    /// Edges it may use now: those the character plays at while it loops,
    /// else only the top (one entrance and standing) — or, for a character
    /// without a top, its other edges.
    private var allowedEdges: FigureEdges {
        let supported = character.geometry.supportedEdges
        if canLoop { return supported }
        return supported.contains(.top) ? .top : supported
    }

    /// A random anchor and edge fully on screen: one where it can play
    /// something other than `lastAction`, on another anchor than `current`
    /// (or another edge of it) when there is one; nil = none.
    private func pick(
        excluding current: AnyHashable?, edge currentEdge: FigureEdge? = nil
    ) -> (id: AnyHashable, edge: FigureEdge)? {
        var generator = SystemRandomNumberGenerator()
        let previous = lastAction
        let state = FigureSignpost.signposter.beginInterval("pick")
        defer { FigureSignpost.signposter.endInterval("pick", state) }
        return FigureAnchorPicker.nextPlacement(
            current: current,
            currentEdge: currentEdge,
            candidates: anchors.map { (id: $0.id, rect: $0.rect, edges: $0.edges) },
            viewport: viewport,
            viewportFor: { viewport(for: $0) },
            sizes: metrics.sizes,
            allowed: allowedEdges,
            offersFresh: { id, rect, edge in
                actions(at: edge, on: rect, anchor: id, from: nil).contains { $0 != previous }
            },
            using: &generator
        )
    }

    /// What it may play at `edge` of `rect` starting at `spot` (nil = it
    /// pops up and picks the spot): the edge's repertoire with the room to
    /// travel there — only the climb at a side by the screen's edge.
    private func actions(at edge: FigureEdge, on rect: CGRect, anchor: AnyHashable?, from spot: Double?) -> [String] {
        let visible = viewport(for: anchor)
        return character.actions(
            at: edge, room: metrics.travelRoom(at: edge, on: rect, viewport: visible, from: spot),
            atScreenEdge: FigureAnchorPicker.isAtScreenEdge(
                rect: rect, edge: edge, viewport: visible, gap: metrics.screenEdgeGap
            )
        )
    }

    /// Where it comes out when nothing is picked and the current edge is not
    /// allowed: the top, or the character's first edge without a top.
    private var fallbackEdge: FigureEdge {
        FigureEdge.allCases.first { allowedEdges.contains($0.member) } ?? .top
    }

    /// Duck behind the card, come out elsewhere (maybe on another card or
    /// edge), play a new action.
    private func tapped() {
        guard !reduceMotion, !isWaiting, !isPinned else { return }
        onTap()
        play(entrance: style.entrance, relocating: true)
    }

    private func appear() {
        chainLeft = 0
        isChained = false
        startDate = nil
        hasPlayed = false
        isHidden = true
        anchorID = nil
        previousAnchorID = nil
        // Pinned and its anchor fits: straight to it, no delay, no draws.
        if pin != nil, showPin() { return }
        var generator = SystemRandomNumberGenerator()
        entranceDelay = style.entranceDelay(using: &generator)
        if entranceDelay > 0 {
            // Stay hidden a moment; `enter()` runs from the delay task.
            isDelayingEntrance = true
            delayID += 1
        } else {
            isDelayingEntrance = false
            enter()
        }
    }

    /// Shows the pin when its anchor is on screen and the figure fits at its
    /// edge: comes out there (or shows the frame at once) and holds the
    /// pose's hold frame. False = the pin doesn't fit now; nothing changed.
    private func showPin() -> Bool {
        guard let pin, let play = FigurePinnedPlay.resolve(
            pin, anchors: anchors, viewport: viewport, metrics: metrics, style: style, character: character
        ) else { return false }
        isPinned = true
        chainLeft = 0
        isChained = false
        isDelayingEntrance = false
        isParked = false
        isPending = false
        isStill = false
        anchorID = play.anchor
        previousAnchorID = play.anchor
        edge = play.edge
        previousEdge = play.edge
        spot = play.spot
        previousSpot = play.spot
        walkTarget = play.spot
        lastAction = play.action
        timeline = play.timeline
        frozenElapsed = play.holdTime
        isHidden = false
        hasPlayed = true
        // Reduce Motion still gets the still frame, only without the motion.
        startDate = pin.animated && !reduceMotion ? .now : nil
        playID += 1
        return true
    }

    /// The first entrance after appearing (once `appearDelay` is over).
    private func enter() {
        if isWaiting {
            // Come out and rest; the cycle carries on after the celebration.
            comeOut(action: FigureActionName.rest)
            isPending = true
        } else {
            comeOut()
        }
    }

    /// Carry on after a celebration or with idle motion back on.
    private func resume() {
        if isHidden { comeOut() } else { play(entrance: nil) }
    }

    /// From behind the cards: out from behind a visible anchor — or wait
    /// (`isParked`) while scrolling or when none is fully on screen.
    private func comeOut(action override: String? = nil) {
        // Already out (two triggers in one update), or still waiting out the
        // first entrance's delay: nothing to do.
        guard isHidden, !isDelayingEntrance else { return }
        guard !isScrolling || !hasPlayed, pick(excluding: anchorID) != nil else {
            isParked = true
            return
        }
        isParked = false
        play(entrance: style.entrance, action: override)
    }

    /// - Parameters:
    ///   - chainStep: the next action of a run, from where it stands (the
    ///     same action may come again).
    ///   - leaving: straight back behind the card (`FigureVariation.leaving`).
    private func play(
        entrance: FigureEntrance?, action override: String? = nil, relocating: Bool = false,
        chainStep: Bool = false, leaving: Bool = false
    ) {
        var generator = SystemRandomNumberGenerator()
        // Start from wherever the figure is right now (mid-walk included).
        let current = position(at: elapsed(at: .now))
        // A tap mid-climb leaves the way the climb does, from the pose shown.
        let shownPose = timeline.anyPose(at: elapsed(at: .now))
        previousSpot = current.spot
        previousAnchorID = current.anchor
        previousEdge = current.edge
        // Out of sight (ducking, or hidden behind the cards): pop up elsewhere.
        let popsUp = relocating || isHidden
        if popsUp {
            let next = pick(excluding: current.anchor, edge: current.edge)
            anchorID = next?.id ?? current.anchor
            edge = next?.edge ?? (allowedEdges.contains(current.edge.member) ? current.edge : fallbackEdge)
        }
        let rect = anchorID.flatMap(rect(for:))
        let visible = viewport(for: anchorID)
        let range = rect.map { spotRange(at: edge, on: $0, anchor: anchorID) } ?? 0...1
        // Room to travel along the edge: a climb needs a tall enough side on
        // screen, a worm walk a wide enough top.
        let room = rect.map {
            metrics.travelRoom(at: edge, on: $0, viewport: visible, from: popsUp ? nil : current.spot)
        } ?? 0
        // Low Power Mode: no action, only the rest pose (and its entrance).
        // Never the last action again while the edge has another.
        let played: String
        if lowPowerMode {
            played = FigureActionName.rest
        } else if let override {
            played = override
        } else {
            let available = rect.map { actions(at: edge, on: $0, anchor: anchorID, from: popsUp ? nil : current.spot) }
                ?? character.actions(at: edge, room: room, atScreenEdge: false)
            if chainStep, available.isEmpty {
                // Nothing fits from here (a climb ended at the top of a side
                // by the screen's edge): the run ends.
                chainLeft = 0
                play(entrance: nil, action: FigureActionName.rest, leaving: true)
                return
            }
            played = FigureRepertoire.next(
                after: chainStep ? nil : lastAction, from: available, fallback: FigureActionName.rest, using: &generator
            )
        }
        // A fresh appearance draws how many actions it plays; other plays
        // (after a celebration, Reduce Motion's rest, leaving) are single.
        let loopsFreely = canLoop && override == nil
        if popsUp, loopsFreely {
            chainLeft = style.actionCount(using: &generator) - 1
        } else if !chainStep {
            chainLeft = 0
        }
        lastAction = played
        let info = character.info(played, at: edge)
        // A side's travelling action (the human's climb) goes up to the top
        // of the visible side, every cycle that fits.
        let travelsToTop = edge.isSide && (info.travelPerBeat ?? 0) > 0
        let span = rect.map { metrics.travelSpan(at: edge, on: $0) } ?? 0
        if popsUp {
            if travelsToTop {
                // As many whole cycles as the visible side holds, starting
                // that far below its top — so the climb always ends at the top.
                let beat = info.travelPerBeat ?? 1
                let cycles = max(1, Int((room + 1e-9) / beat))
                spot = FigurePlacement.travelTarget(
                    from: range.lowerBound, distance: Double(cycles) * beat, direction: 1, scale: metrics.scale, span: span
                )
            } else if anchorID == current.anchor, edge == current.edge {
                spot = FigurePlacement.next(from: current.spot, using: &generator)
            } else {
                spot = Double.random(in: range, using: &generator)
            }
        } else {
            spot = current.spot
        }
        spot = min(max(spot, range.lowerBound), range.upperBound)
        // A climb to the top of a side where nothing else fits from there (by
        // the screen's edge it only climbs) ends the run: it leaves its own
        // way from the top instead of standing there to lean out and go back.
        if travelsToTop, chainLeft > 0, let rect,
           actions(at: edge, on: rect, anchor: anchorID, from: range.lowerBound).isEmpty {
            chainLeft = 0
        }
        isChained = loopsFreely && chainLeft > 0
        var variation = leaving
            ? FigureVariation.leaving(exit: style.entrance, using: &generator)
            : loopsFreely
                ? FigureVariation.random(repeats: info.repeatRange, exit: style.entrance, using: &generator)
                    .chained(continues: isChained)
                : .standard
        // Travelling actions: as many beats as fit from this spot (the top
        // walks toward the wider side).
        let forward = edge == .top && spot > 0.5 ? -1.0 : 1.0
        if let beat = info.travelPerBeat {
            let fromSpot = rect.map { metrics.travelRoom(at: edge, on: $0, viewport: visible, from: spot) } ?? 0
            // The climb goes all the way up: every cycle that fits.
            let wanted = travelsToTop ? Int.max : variation.repeats ?? info.defaultRepeats
            variation.repeats = max(1, min(wanted, Int((fromSpot + 1e-9) / beat)))
        }
        timeline = character.play(FigurePlayRequest(
            action: played, entrance: entrance, reduceMotion: reduceMotion, edge: edge,
            relocating: relocating, previousEdge: current.edge, previousPose: shownPose,
            tempo: style.tempo, variation: variation
        ))
        isHidden = false
        isStill = false
        if let distance = timeline.walkDistance {
            // Exactly as far as the limbs carry it: up a side, along the top.
            walkTarget = FigurePlacement.travelTarget(
                from: spot, distance: distance, direction: edge.isSide ? -1 : forward, scale: metrics.scale, span: span
            )
        } else if timeline.walkWindow == nil {
            walkTarget = spot
        } else {
            walkTarget = FigurePlacement.next(from: spot, using: &generator)
        }
        hasPlayed = true
        startDate = .now
        playID += 1
    }
}

/// A step of `PeekingFigureView`'s timing tasks, for the delay or play it
/// belongs to (`delayID` / `playID`): stale ones are dropped.
enum FigureDue: Equatable {
    /// The first entrance's delay is over.
    case entrance(Int)
    /// A one-shot play ended.
    case playEnded(Int)
    /// A looped cycle's pause behind the card is over.
    case pauseEnded(Int)
}

/// Clips to `rect` in the view's own space; nil = no clip.
struct FigureRegionClip: Shape {
    let rect: CGRect?

    func path(in bounds: CGRect) -> Path {
        Path(rect ?? bounds.insetBy(dx: -10_000, dy: -10_000))
    }
}
