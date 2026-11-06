# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org); until 1.0 the public API may still
change in minor releases.

## Unreleased

- Top edge: the walk is replaced by a caterpillar **worm walk** (in profile,
  lying on the edge; travels exactly as far as its hands and feet carry it)
  and a new **handstand** (half a cartwheel onto the hands, a balance wobble).
- Side edges: the **climb** happens outside the card, facing it, hand over
  hand, and always goes up; it is only played where enough of the side is on
  screen (~136 pt at the default height).
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
