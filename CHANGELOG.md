# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org); until 1.0 the public API may still
change in minor releases.

## Unreleased

- Top edge: the walk is replaced by a caterpillar **worm walk** (in profile,
  lying on the edge; travels exactly as far as its hands and feet carry it)
  and a new **handstand** (half a cartwheel onto the hands, a balance wobble).
- Side edges: the figure plays **beside the card**, outside its edge — the
  card hides whatever is behind it, nothing plays over the card. It slides out
  from behind the edge; the peek hangs out holding the edge; the **flag** is a
  human flag (hands wide apart on the edge, upper arm straight, never
  crossed); the **climb** faces the card, goes hand over hand and always up,
  and is only played where enough of the side is on screen (~136 pt at the
  default height). A side needs that edge on screen; the figure past it may be
  cut by the screen's edge.
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
- Edge weights: 25 % each.

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
