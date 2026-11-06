# EdgeBuddy

A tiny stick figure that lives on the edges of your SwiftUI cards.

EdgeBuddy adds one small, single-colour figure to a screen. It comes out from
behind a card you mark, plays a short random action, goes back and comes out
somewhere else:

- **top edge** — stands on it: rests, waves, does jumping jacks, stretches,
  marches, inches along it like a caterpillar (worm walk), cartwheels into a
  handstand or runs along the edge;
- **bottom edge** — hangs under it (wide grip): swings like a pendulum, pulls
  itself up;
- **leading / trailing edge** — peeks around it, holds itself out past it like
  a flag, climbs up its outside hand over hand (only where enough of the side
  is on screen).

A tap sends it to another card. It rides along while the content scrolls and
waits for the scroll to stop before coming out again.

<!-- TODO: GIFs — a screen with several cards (top + bottom + sides), a single
     onboarding card, the running loader. Record on an iPhone simulator in light
     and dark mode, ~6 s each, and put them in `docs/media/`. -->

## Requirements

- iOS 18+ (also builds for macOS 15+)
- Swift 6 (strict concurrency), Xcode 16+

## Installation

Swift Package Manager — in Xcode: **File › Add Package Dependencies…** and
enter the URL, or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Jojogurt/EdgeBuddy.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["EdgeBuddy"]),
]
```

XcodeGen (`project.yml`):

```yaml
packages:
  EdgeBuddy:
    url: https://github.com/Jojogurt/EdgeBuddy.git
    from: 0.1.0
```

## Quick start

### A screen with several cards

Put one stage on the screen's `ScrollView` and mark the cards the figure may
come out from behind:

```swift
import EdgeBuddy
import SwiftUI

struct TodayScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeroCard()
                    .figureAnchor("hero", edges: .all)
                StatsCard()
                    .figureAnchor("stats")                 // top only
                ForEach(items) { item in
                    ItemCard(item)
                        .figureAnchor(item.id, edges: [.top, .trailing])
                }
            }
            .padding()
        }
        .figureStage()
    }
}
```

- Anchor ids must be unique among the stage's anchors.
- Anchors take no space and change nothing without a stage.
- The figure stands *above* a card's top edge — leave some room above the
  first card (about the figure's height, 56 pt by default).

### A single card

For one-off cards (onboarding, empty states) there is no stage to set up:

```swift
EmptyStateCard()
    .peekingFigure()
```

It comes out at the card's top edge only. It takes no space: where the card
is the first thing in a scroll view, leave room above it or use
`scrollClipDisabled()`.

### Holding the stage

While something else needs the screen (a celebration, a sheet animating in),
pass `isWaiting: true`; the figure stays where it is and carries on afterwards:

```swift
.figureStage(isWaiting: isCelebrating)
```

`loops: false` makes it come out once and stand; `isEnabled: false` removes it.

## Edges and weights

`figureAnchor(_:edges:)` takes a `FigureEdges` set: `.top` (default),
`.bottom`, `.leading`, `.trailing` or `.all`. Each cycle the stage picks a
random anchor that is fully on screen (never the same one twice in a row when
there is another), then an edge of it, evenly:

| Edge | Weight | Needs |
|---|---|---|
| top | 25 % | ~108 pt wide; room above the card on screen |
| bottom | 25 % | ~108 pt wide; room under the card on screen |
| leading / trailing | 25 % each | ~82 pt of the card's height on screen |

Weights are renormalized over the edges that are possible right now. Some
actions need more room: the climb needs ~136 pt of the side on screen (it
climbs at least ~54 pt), the worm walk ~33 pt of free width on one side of
it; elsewhere the edge simply plays its other actions. Sizes scale with
`figureHeight(_:)`.

## Customization

All settings are environment values — set them on the stage or anywhere
above it (for example once at your app's root):

```swift
.figureStage(style: FigureStyle(entrance: .spring, tempo: 1.2, appearDelay: 0.8...2))
.figureColor(.accentColor)      // single colour; dynamic colours follow dark mode
.figureOpacity(0.8)             // softer on the cards; 1 by default
.figureHeight(56)               // points; everything else scales from it
.figureHaptics(true)            // selection haptic on tap
.figureMotionEnabled(nil)       // nil = built-in policy, or your app's own Bool
```

- **Colour** — default `Color.accentColor`.
- **Opacity** — `figureOpacity(_:)`, 0…1, default 1 (say 0.8 to sit softer
  on the cards).
- **Size** — default 56 pt (the height above a top edge). Width, margins and
  the footprint at the other edges scale with it.
- **Haptics** — `.sensoryFeedback(.selection)` on tap, on by default.
- **Motion** — the built-in policy lets the figure loop only while the scene
  is active and Reduce Motion and Low Power Mode are off. If your app has its
  own idle-motion setting, pass it with `figureMotionEnabled(_:)`; it replaces
  the built-in policy (Reduce Motion and Low Power Mode still stop the loop).
- **Style** — `FigureEntrance.climb` (default: grabs the edge and climbs up)
  or `.spring` (pops straight up); `tempo` scales the speed; `appearDelay`
  (default 0.8…2 s, drawn at random, scaled by tempo) keeps it hidden for a
  moment after the screen appears before its first entrance — `0...0` comes
  out at once. Later cycles and taps don't wait.

### Running figure

`RunningFigure` is the same figure in profile, running in place — handy for a
loading indicator:

```swift
TimelineView(.animation) { context in
    RunningFigure(
        phase: context.date.timeIntervalSinceReferenceDate / RunningFigure.cycleDuration,
        color: .green
    )
}
.frame(width: 54, height: 56)
.accessibilityLabel("Loading")
```

## Accessibility

- The figure is decoration: hidden from VoiceOver, and it never takes taps
  meant for the content under it (only the figure itself is tappable, and only
  once it is out).
- Hidden at accessibility text sizes (AX1 and larger), where it would cover
  too much of the larger text.
- Reduce Motion: no loop, no tap relocation — it fades in and stands.
- Low Power Mode: no loop and no actions — it comes out once and rests.
- It stops while the scene is not active and its clock stops while it is off
  screen or holding still.

## Limitations

- Not in `List` or `Form`: their rows are recycled and clipped, so anchors
  inside them are unreliable. Use a `ScrollView` with a lazy or plain stack.
- One stage per screen. Anchors belong to the nearest stage above them.
- In lazy stacks, cards far off screen have no frame; the figure simply uses
  the ones that are laid out.

## Example

`Examples/EdgeBuddyDemo` is a one-file demo app — see its README.

## License

MIT — see [LICENSE](LICENSE).
