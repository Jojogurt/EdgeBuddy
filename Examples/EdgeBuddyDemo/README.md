# EdgeBuddyDemo

A one-file SwiftUI app showing EdgeBuddy: a scrolling screen of cards with one
figure, live colour / height / haptics settings, a "hold the stage" switch and
a `RunningFigure` loader.

## Run it

1. In Xcode, create a new iOS App project (SwiftUI, iOS 18 or later).
2. Add the package: **File › Add Package Dependencies… › Add Local…** and pick
   the root of this repository (or use the GitHub URL), then add the
   `EdgeBuddy` library to the app target.
3. Replace the generated `…App.swift` and `ContentView.swift` with
   `EdgeBuddyDemoApp.swift` from this folder.
4. Run on an iPhone simulator or device. Scroll, tap the figure, and try the
   settings.
