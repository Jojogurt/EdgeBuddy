# BACKLOG

Persistent record of design discussions, decisions, and phase status. New entries on top; completed (collapsed) at the bottom.

---

## Audit 0.2.0 → roadmap 0.3.0 (2026-11-07)

Context: audit of the 0.2.0 public repo (code, API, a11y, tests/CI, README, demo) plus a
scan of similar projects. Overall healthy: motion is separated from drawing
(`FigureJoints` → `FigureSkeleton` → `FigureCanvas`), 74 Swift Testing tests, Swift 6
strict, `TimelineView` pauses when still/off screen, no blocking work on main.

Competition (researched): no SwiftUI package with an edge-aware figure on views was
found. Closest: desktop pets (Shimeji-ee, MacPenguins, OpenPetsKit), oneko.js,
the "Peekaboo" Chrome extension (product, not a library), Rive (designer-driven,
no view geometry). Takeaways: README needs a GIF; never bundle third-party sprites
(GPL/licensing); position as "delight" for onboarding/empty/success states.

Decisions:
- Order: measure → stage anywhere → demo → custom figure — numbers first, so later phases have a baseline.
- Stage: `figureStage()` works on any view incl. a screen's `body` — each ScrollView reports its visible rect/insets, the stage clips per anchor; sheets stay separate hierarchies (documented).
- Custom figure: `FigureAppearance` first, then a public renderer closure — biggest effect for the cost; renderer freezes the skeleton model as API, so design it carefully.
- Demo: committed `.xcodeproj` (iOS + macOS), tabs Playground / Pinning / Static / Single card, built in CI — opens without XcodeGen.

### Phase 1 — Measurement, CI, RTL
- Perf tests for pure code (`FigureTimeline.joints(at:)`, `FigureSkeleton.init`, IK `placing`, `FigureAnchorPicker` at 10/100/1000 anchors); `os_signpost` around hot paths; Instruments (SwiftUI + Hitches) on a device: 30-card scroll with and without the figure, idle CPU ≈ 0%.
- Cut per-scroll-frame work while hidden/parked (`anchors.map`, `isOnScreen`, `onChange(of: anchors.map(\.id))` in `PeekingFigureView.swift:139`).
- CI: run tests on the iOS Simulator too (today iOS is build-only), pin the Xcode version.
- RTL: `.leading`/`.trailing` are physical left/right (no `layoutDirection` in Sources) — verify with an RTL pseudo-language, then map or rename; add a test.
- Small fixes: one source of truth for Low Power (`canLoop`/`play` read `ProcessInfo` directly), react to Reduce Motion changing mid-action, clamp `figureHeight` when set, reclamp `spot` on viewport change.
- **Done (2026-11-07, uncommitted):** `PerformanceTests.swift`, `FigureSignpost.swift` (signposts `joints`, `pick`), hidden/parked early-out + `anchorSignature` hash in `PeekingFigureView`, single Low Power source, Reduce Motion mid-action, `clampedHeight`, `reclampSpot`, CI (macos-15, Xcode 16.4, iOS Simulator tests), `LayoutDirectionTests`. 81 tests green on macOS and iPhone 17e Simulator.
- **Baseline (release build, M-series Mac, `swift test -c release -Xswiftc -enable-testing --no-parallel --filter PerformanceTests`; mean per call):**
  - `FigureTimeline.joints(at:)`: 0.05–0.1 µs (top: wave/jacks/march/stretch/run), 0.56–0.87 µs (handstand, worm walk), 0.73–1.0 µs (bottom, sides, incl. IK). ≈ 0.001 % of a 120 Hz frame.
  - `FigureTimeline.init`: 0.37–1.03 µs (run 1.03 is the slowest).
  - `FigureSkeleton.init`: 0.17 µs. IK `placing`: 0.19 µs (1 limb), 0.81 µs (4 limbs).
  - `FigureAnchorPicker.nextPlacement`: 13 µs (10 anchors), 46 µs (100), 363–400 µs (1000) — linear; only runs per play, not per frame.
  - Debug builds are ~50–100× slower (Simulator under load ~100×): test budgets are relaxed 200× in DEBUG.
  - **Device (iPhone 14 Pro, iOS 27.0.1, Release, 2026-11-07)** — 30-card `LazyVStack` of `figureAnchor(edges: .all)`, scripted linear scroll 24 s (3× down/up), `CADisplayLink` frame meter + process CPU (host app outside the repo, `/Volumes/Lexar SSD/DevCache/edgebuddy-perf-host`):
    - no figure: 1839 frames, median 16.68 ms (60 Hz link), max 16.72 ms, **0 hitches**, scroll CPU 16.7 %, idle CPU 0.5 %.
    - figure, loops: 1876 frames, max 16.71 ms, **0 hitches**, scroll CPU 22.7 % (+6 pts), idle CPU 4.9 % while it plays actions.
    - figure, `loops: false` (rests after entrance): 1888 frames, max 16.72 ms, **0 hitches**, scroll CPU 22.2 %, **idle CPU 0.2 %**.
    - Caveats: link capped at 60 Hz (no `CADisableMinimumFrameDurationOnPhone`), so ProMotion 120 Hz untested; CPU is whole-process; `xctrace` Animation Hitches could not record over Wi-Fi ("waiting for device to boot" / attach failed) — needs USB for Instruments traces. Signposts `joints`/`pick` are ready for that.
- **RTL finding:** `proxy[anchor]` rects are physical in RTL (verified on macOS and iOS Simulator, `LayoutDirectionTests`: first HStack item is at x=250 in RTL), so `.leading` / `.trailing` currently mean physical left / right, while `FigureEdges` docs say "leading edge". **Decided: map (done, `FigureEdges.physical(for:)` applied in the stage to anchors and pin).** Options were: map through `layoutDirection` (logical, matches docs and SwiftUI conventions; mirror physical edge in `figureFrame`/picker/mirroring) vs rename to `.left`/`.right`. `EdgeMappingTests` cover it.
- [x] Discussed
- [ ] Researched
- [x] Planned
- [x] Executed (Instruments traces over USB still to do)
- [x] Committed

### Phase 2 — Stage anywhere
- Today: viewport = the stage's whole rect; cards under translucent bars count as on screen and the figure can draw over bars (`FigureRig.swift:1503`); with several ScrollViews it is unclear which one drives `isScrolling` (verify on iOS 18).
- Goal: `figureStage()` on any view, incl. above `NavigationStack`/`TabView`. Each ScrollView reports its visible rect + content insets (`onScrollGeometryChange`) and scroll phase via preference; the stage intersects per anchor and clips there.
- Keep the current `figureStage` on a ScrollView source-compatible.
- **Done (2026-11-07, uncommitted):** research on iOS 27 Simulator: `GeometryProxy.bounds(of: .scrollView)` gives the scroll view's frame *between its bars* (608 pt of 844 with large title + tab bar; tracks the title collapsing), `onScrollPhaseChange` on an ancestor reports phases of descendant scroll views (through TabView/NavigationStack) but without identity → counted (`FigureScrollTracker`). `FigureAnchorModifier` stores the region (global space, constant while scrolling → no per-frame state), `FigureAnchorFrame.viewport` carries it per anchor, picker/pin/actions/spot ranges use it, canvas clipped per anchor (`FigureRegionClip`). Verified visually: stage on a VStack with a bar + two scroll views, and on a ScrollView inside NavigationStack.
- **Finding / deviation from the goal:** a stage *above* `NavigationStack`/`TabView` does NOT work — preferences do not propagate out of those containers (figure never shows). It works anywhere inside a page. Supporting the outer placement would need an environment-held anchor registry (anchors push frames each scroll frame) — parked, see Deferred.
- Known limits: scroll counter can stick if a scroll view is removed mid-scroll; occlusion by non-bar views not detected (documented).
- Document: sheets/popovers/pushed screens need their own stage; occlusion by other views is not detected (`isWaiting` for modals); "behind the card" is a rectangular clip — rounded corners near the edge ends.
- [x] Discussed
- [x] Researched
- [x] Planned
- [x] Executed (inside a page; above NavigationStack/TabView parked)
- [x] Committed

### Phase 3 — Demo + README GIF
- `Examples/EdgeBuddyDemo` as a committed `.xcodeproj`, multiplatform iOS + macOS, local package reference.
- Tabs: Playground (colour, height, opacity, tempo, entrance, appearDelay, haptics, isWaiting), Pinning (pose/anchor/edge/spot/animated), Static (no ScrollView, stage on the screen body), Single card (`peekingFigure`).
- Build it in CI; record a GIF/video for the README.
- **Done (2026-11-07, uncommitted):** `Examples/EdgeBuddyDemo/{project.yml,Sources/,EdgeBuddyDemo.xcodeproj}` (xcodegen, `supportedDestinations: [iOS, macOS]`, local package path `../..`), `.gitignore` exception for the demo xcodeproj, 4 tabs; builds clean for iOS Simulator and macOS; CI builds both; `Examples/Media/demo.gif` (iPhone 17e Simulator, 360 px, ~100 KB) embedded in README. GIF shows the Playground tab only.
- [x] Discussed
- [x] Researched
- [x] Planned
- [x] Executed
- [ ] Committed

### Phase 4 — Custom figure
- Step 1: `FigureAppearance` — head as `Image`/emoji/SF Symbol (handle tilt + mirroring), limb/torso width, head size, per-part colour.
- Step 2: public renderer — closure gets the skeleton points (hip, torsoTop, head, arms, legs, far-limb opacity), `GraphicsContext` and size/viewBox. Name clash: `FigurePose` is already the pinned-pose enum — pick another name (e.g. `FigureSkeletonPoints`).
- The stage keeps clipping, hit testing and mirroring; custom drawing must fit the viewBox.
- Sprite sheets rejected: poses are continuous (IK), frames would lose smoothness.
- [x] Discussed
- [ ] Researched
- [ ] Planned
- [ ] Executed
- [ ] Committed

---

## Deferred (parking lot)

- Stage above `NavigationStack`/`TabView`: environment-held anchor registry instead of preferences (cost: per-frame pushes from every anchor; measure first).
- CONTRIBUTING.md, SECURITY.md, issue/PR templates.
- DocC articles (Getting Started, Snapshots, Custom figure).
- Snapshot/regression tests of `FigureCanvas` via `ImageRenderer` + `figurePinned(animated: false)`.
- Reacting to the pointer on macOS/iPad (hide when the cursor comes near, like Peekaboo).
- Community skins gallery (a list of renderers/appearances), never bundling third-party art.
- Naming consistency: `peekingFigure` vs the `figureX` family.

## Completed (collapsed)
