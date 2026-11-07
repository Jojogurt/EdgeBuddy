# ``EdgeBuddy``

A tiny stick figure that lives on the edges of your SwiftUI cards.

## Overview

EdgeBuddy adds one small, single-colour figure to a screen. It comes out
from behind a card you mark, plays a short random action — waves, jumping
jacks, a stretch, marching, a caterpillar worm walk, a handstand or a run on
the top edge; hangs, swings and pulls itself up under the bottom edge;
beside the sides, outside the card, holding its edge: hangs out and looks
around, does a human flag or climbs up the edge (where enough of the side is
on screen; a side at the screen's edge only climbs) — then goes back and comes out somewhere else, never with the same
action twice in a row. A tap sends it elsewhere. It waits a moment after the screen appears
before it first comes out (``FigureStyle/appearDelay``).

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
- ``SwiftUICore/View/figureOpacity(_:)``
- ``SwiftUICore/View/figureHeight(_:)``
- ``SwiftUICore/View/figureHaptics(_:)``
- ``SwiftUICore/View/figureMotionEnabled(_:)``

### Characters

The default character is ``HumanFigure``; its parameters change the look
(head, thickness, colour per part). A type of your own conforming to
``FigureCharacter`` brings its own pose model, actions per edge, boxes and
drawing — a ghost without arms or legs, say. The stage keeps sequencing,
layout, taps, Reduce Motion, Low Power Mode and pins.

```swift
.figureStage()
.figureCharacter(HumanFigure(head: .text("🐻"), headScale: 1.4))
```

- `figureCharacter(_:)` (a concrete character, or `any FigureCharacter` chosen at run time)
- ``HumanFigure``
- ``FigureHead``
- ``FigureCharacter``
- ``FigureCharacterPose``
- ``FigureCharacterAction``
- ``FigureMotion``
- ``FigureCharacterBox``
- ``FigureEdge``
- ``FigureSkeletonPoints``

### Snapshots & previews

A pinned figure stands still in a known place — for App Store screenshots,
Xcode previews and snapshot tests: no entrance delay, no random picks, no
loop, no taps; it plays the pose and freezes at its hold frame (also under
Reduce Motion and Low Power Mode). When the anchor is off screen or the
figure doesn't fit at that edge, the stage plays as without a pin. A single card
(`peekingFigure`) takes ``FigurePin/singleCard(edge:pose:spot:animated:)``.

```swift
.figureStage()
.figurePinned(FigurePin(anchor: "hero", edge: .trailing, pose: .flag, animated: false))
```

- ``SwiftUICore/View/figurePinned(_:)``
- ``FigurePin``
- ``FigurePose``

Pins name a character's action (``FigurePin/init(anchor:edge:action:spot:animated:)``);
``FigurePose`` is the list of ``HumanFigure``'s.

### Building blocks

- ``RunningFigure``
