# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org); until 1.0 the public API may still
change in minor releases.

## 0.4.0 — 2026-11-09

- New: `FigureStyle.actionsPerCycle` — how many actions the figure plays each time it comes
  out, drawn from the range (`1...1` by default, as before). Between them it stands a moment
  on the same edge (a climb or a worm walk may carry it along); the same action may come again,
  only an action with room from where it stands is drawn (no second climb after reaching the
  top). A scroll ends the run once the action playing finishes, then it goes back behind the
  card; a tap starts a new run elsewhere. Only while it loops. Demo: Playground's "Actions per
  appearance".

## 0.3.3 — 2026-11-09

- Fix: a figure on the side of a card in a horizontal pager with `.contentMargins` was cut at
  the card's edge although the margin beside it was empty. A pager's bounds leave out its content
  margins, so since 0.3.1 they ended at the card. The visible area may now reach past the pager's
  bounds by the figure's side box (never past the vertical scroll view), so the figure uses the
  margin. Only the card of the page shown gets it: a card of the next page peeking into the
  margin never gets the figure on its side. The measured area no longer changes on every
  scroll frame of a card in a pager.
- Fix: after a cycle's pause behind the card the figure could come out mid-scroll, from
  frames of a few seconds ago, or stay hidden until the next scroll. The timing tasks kept
  the view's inputs from when they started; they now only signal, and the stage decides with
  the current ones.
- Fix: a viewport change once a scroll stopped (pull to refresh, a bar resizing) could clamp
  a climb into one spot — the figure jumped to the top of the card and climbed in place. Such
  a change now leaves the climb on its path.

## 0.3.2 — 2026-11-08

- Fix: a figure on a card's side could jump when the screen scrolled. The large title
  collapsing (or snapping back) changes the visible area mid-scroll; 0.3.1 then clamped the
  figure to the part of the card still visible once the scroll stopped, moving a running climb
  off its path. Viewport changes caused by a scroll no longer move the figure — it stays on its
  card as the card goes under the bar, like with any scroll; only layout changes clamp it.
- The visible area is rounded to 1/100 pt: its measure jittered by ~1e-14 on every scroll
  frame, which counted as a change each frame.
- Demo: a Pager tab — cards in a horizontal pager inside a vertical `ScrollView` under a large
  title, with "Sides only" (`-EdgeBuddyPagerSides YES`) so the figure climbs often.

## 0.3.1 — 2026-11-07

- Fix (regression in 0.3.0): an anchor inside a horizontal pager (`ScrollView(.horizontal)`
  with `.scrollTargetBehavior(.paging)`) nested in the screen's vertical `ScrollView` took the
  pager as its visible area. The figure was cut off just above the card and beside it, and while
  it climbed a side and the screen scrolled up, it slid along the navigation bar's bottom edge
  instead of staying on the card going under the bar. An anchor's visible area now takes Y from
  the closest vertical scroll view and X from the closest horizontal one (the pager still cuts off
  the cards of other pages), so it no longer changes while the screen scrolls.
- A side spot is clamped to a changed viewport once the scroll stops, not on every scroll frame.
- Demo: the Playground tab has cards in a horizontal pager inside its vertical `ScrollView`.

## 0.3.0 — 2026-11-07

- Fix: right after launch the figure could come out once and stand still forever — when looping became
  allowed (the scene turning active) while the first play was still running, nothing resumed the loop.
- Performance baseline: Swift Testing timings of the pure hot paths
  (`FigureTimeline.joints(at:)`, `FigureSkeleton.init`, IK `placing`,
  `FigureAnchorPicker` at 10 / 100 / 1000 anchors) and `os_signpost`
  intervals (Points of Interest: `joints`, `pick`) for Instruments.
- Less work per scroll frame while the figure is hidden or parked: no pose or
  drawing, and anchor changes are detected with a hash instead of an id array.
- Low Power Mode has a single source (the stage's state); Reduce Motion
  turning on mid-action settles the figure into the rest pose at once.
- `figureHeight(_:)` clamps when set (non-finite falls back to the default);
  a side spot is clamped again when the viewport changes.
- Right-to-left: `FigureEdges.leading` / `.trailing` (also in `FigurePin`) now follow the
  layout direction — leading is the right side in RTL layouts, as documented.
- Stage on any view: each marked view reports the visible area of its own
  scroll view (between the navigation and tab bars), so cards under translucent
  bars no longer count as on screen, the figure is clipped there, and several
  scroll views under one stage (columns, header + list) work independently.
  Scroll phases of all of them are counted, not a single flag. The stage must
  sit inside a `NavigationStack` page / tab, not above it (SwiftUI does not
  pass preferences out of those containers).
- CI: tests also run on the iOS Simulator; Xcode pinned to 16.4; the demo app is built for iOS Simulator and macOS.
- Demo: `Examples/EdgeBuddyDemo` is a committed multiplatform `.xcodeproj` with four tabs
  (Playground, Pinning, Static, Single card); a GIF in the README.
- **Characters.** `figureCharacter(_:)` sets who plays. `FigureCharacter` describes a whole
  character: its own `Pose` (`FigureCharacterPose`: `interpolated(to:_:)`), per edge
  (`FigureEdge`, now public) the drawn box and the card's edge line (`FigureCharacterBox`,
  `referenceHeight` = what `figureHeight` sets), its actions (`FigureCharacterAction`: name,
  one beat of `FigureMotion`, repeats, travel along the edge, pin hold, `playsAtScreenEdge`;
  no actions = edge unused), rest and hidden poses, an optional entrance (default: rise from
  hidden to rest, exit = backwards) and `draw(_:in:color:)`. The stage sequences plays, picks
  cards/edges/spots, lays out, hit-tests and clips from the character's boxes, and keeps Reduce
  Motion, Low Power Mode, pins and RTL as before. See the `Ghost` in the demo.
- **`HumanFigure`** is the built-in stick figure behind that protocol (unchanged motion, layout
  and taps) and carries the look as parameters: `head` (`FigureHead`: circle, SF Symbol,
  text/emoji, image), `headScale` / `limbScale` / `torsoScale` (0.6…1.5), `headColor` /
  `torsoColor` / `armColor` / `legColor`, `mirrorsHead`. `HumanFigure.Pose.points` gives the
  joints as `FigureSkeletonPoints`. `RunningFigure(phase:color:viewBox:figure:)` takes a
  `HumanFigure` for its look.
- Pins name actions: `FigurePin(anchor:edge:action:spot:animated:)`,
  `FigurePin.singleCard(edge:action:spot:animated:)`, `FigurePin.action`; `FigurePose` stays
  as the `HumanFigure`'s poses (now `String`-raw-valued) and `FigurePin.pose` is optional.
- **Replaces the earlier unreleased look API** (never in a release): `FigureAppearance`,
  `figureAppearance(_:)`, `FigureAppearance.character`, the draw-only `FigureCharacter` and
  `Stickman` are gone — use `.figureCharacter(HumanFigure(head:…))` for the look and a
  `FigureCharacter` of your own for a different figure; `RunningFigure(appearance:)` is now
  `RunningFigure(figure:)`. Custom heads are drawn straight into the `GraphicsContext`
  (resolved symbol/text/image) instead of Canvas symbols.

## 0.2.0 — 2026-11-07

- **Pinned figure** for screenshots, previews and snapshot tests:
  `figurePinned(_:)` with `FigurePin(anchor:edge:pose:spot:animated:)` and the
  public `FigurePose`. No entrance delay, no random picks, no loop, no tap
  relocation; it plays the pose and freezes at its hold frame, also under
  Reduce Motion and Low Power Mode. Falls back to the free stage while the
  anchor is off screen or the figure doesn't fit at that edge.
- Top edge: the walk is replaced by a caterpillar **worm walk** (in profile,
  lying on the edge; travels exactly as far as its hands and feet carry it)
  and a new **handstand** (half a cartwheel onto the hands, a balance wobble).
- Side edges: the figure plays **beside the card**, outside its edge — the
  card hides whatever is behind it, nothing plays over the card. It slides out
  from behind the edge; the peek hangs out holding the edge; the **flag** is a
  human flag (hands wide apart on the edge, upper arm straight, never
  crossed); the **climb** faces the card, goes hand over hand and always up to the top of the visible side,
  and is only played where enough of the side is on screen (~136 pt at the
  default height). A side needs that edge on screen; the figure past it may be
  cut by the screen's edge.
- The side climb comes out and goes back on its own: from behind the card a
  hand grips the edge, then the other higher, the body swings out already in
  profile facing the card and the feet find the edge; it leaves the same way
  backwards (body in first, hands let go last), also when tapped mid-climb.
  Turns between the peek and the climb no longer squash the figure flat.
- The side flag does the same: from behind the card the upper hand grips the
  edge, then the lower, and the body swings out straight into the flag; it
  leaves backwards (body in, lower hand, then upper), also when tapped
  mid-flag.
- A side less than 28 pt (scaled with the figure's height) from the screen's
  edge only climbs, and is used only where the climb fits; sides facing other
  content keep the full repertoire. Single cards are never at the edge.
- Never the same action twice in a row (also after rest-only plays, taps and
  relocations), preferring a card or edge that offers something new, and
  never the same edge of the same card twice when there is another.
- Hands and feet on an edge are held by two-bone IK while sampling, so grips
  no longer slip or cross (hang, swing, pull-up, the bottom entrance, flag,
  climb, handstand); bent arms under the bottom edge bend outward.
- `FigureStyle.appearDelay` (default 0.8…2 s): a short wait before the first
  entrance after a screen appears.
- `figureOpacity(_:)`.
- Edge weights: 25 % each (were 60 / 20 / 10 / 10 %).

## 0.1.0 — 2026-11-06

First release, extracted from the Nextleg app.

- `figureStage(isEnabled:style:isWaiting:loops:)` — one figure per screen,
  coming out from behind marked views of a `ScrollView`.
- `figureAnchor(_:edges:)` — marks a view; `FigureEdges` picks the edges
  (top, bottom, leading, trailing) with weights 60 / 20 / 10 / 10 %.
- `peekingFigure(isEnabled:style:isWaiting:loops:)` — a figure on a single card.
- `FigureStyle` / `FigureEntrance` — climb or spring entrance, tempo.
- Customization: `figureColor(_:)`, `figureHeight(_:)`, `figureHaptics(_:)`,
  `figureMotionEnabled(_:)` (overrides the built-in idle-motion policy).
- `RunningFigure` — the figure running in place, for loading indicators.
- Accessibility: hidden from VoiceOver and at accessibility text sizes;
  Reduce Motion, Low Power Mode and inactive scenes stop the loop.
