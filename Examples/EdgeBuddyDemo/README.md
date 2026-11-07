# EdgeBuddyDemo

A multiplatform (iOS 18 + macOS 15) SwiftUI app showing EdgeBuddy. It
references the package in this repository by path, so it always runs the
local sources.

## Run it

Open `EdgeBuddyDemo.xcodeproj` in Xcode 16 or later, pick an iPhone simulator
or "My Mac" and run. No XcodeGen needed; `project.yml` is only the source the
project was generated from (`xcodegen generate` in this folder).

## Tabs

| Tab | Shows |
|---|---|
| Playground | `figureStage` on a `ScrollView`; colour, height, opacity, tempo, entrance, appear delay, loops, haptics, `isWaiting`; `RunningFigure` as a loader |
| Pinning | `figurePinned` with a stage on the whole screen: anchor, edge, pose, spot, animated |
| Static | no `ScrollView` — the stage on a screen's `body` |
| Single card | `peekingFigure()` for one-off cards |
