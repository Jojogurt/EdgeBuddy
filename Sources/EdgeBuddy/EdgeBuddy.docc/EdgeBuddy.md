# ``EdgeBuddy``

A tiny stick figure that lives on the edges of your SwiftUI cards.

## Overview

EdgeBuddy adds one small, single-colour figure to a screen. It comes out
from behind a card you mark, plays a short random action — waves, jumping
jacks, a stretch, a walk or a run along the top edge; hangs, swings and pulls
itself up under the bottom edge; peeks, holds a flag or climbs at the sides —
then goes back and comes out somewhere else. A tap sends it elsewhere.

It is decoration only: hidden from VoiceOver, hidden at accessibility text
sizes, calm under Reduce Motion and Low Power Mode, and paused while the
scene is not active.

```swift
ScrollView {
    VStack(spacing: 16) {
        HeroCard().figureAnchor("hero", edges: .all)
        StatsCard().figureAnchor("stats")
    }
}
.figureStage()
.figureColor(.green)
```

For a single card (onboarding, an empty state) use
``SwiftUICore/View/peekingFigure(isEnabled:style:isWaiting:loops:)``.

## Topics

### Placing the figure

- ``SwiftUICore/View/figureStage(isEnabled:style:isWaiting:loops:)``
- ``SwiftUICore/View/figureAnchor(_:edges:)``
- ``SwiftUICore/View/peekingFigure(isEnabled:style:isWaiting:loops:)``
- ``FigureEdges``

### Style

- ``FigureStyle``
- ``FigureEntrance``

### Customization

- ``SwiftUICore/View/figureColor(_:)``
- ``SwiftUICore/View/figureHeight(_:)``
- ``SwiftUICore/View/figureHaptics(_:)``
- ``SwiftUICore/View/figureMotionEnabled(_:)``

### Building blocks

- ``RunningFigure``
