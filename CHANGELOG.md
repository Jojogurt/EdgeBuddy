# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org); until 1.0 the public API may still
change in minor releases.

## 0.1.0 — unreleased

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
