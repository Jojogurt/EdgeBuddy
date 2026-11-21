# BACKLOG

Persistent record of design discussions, decisions, and phase status. New entries on top; completed (collapsed) at the bottom.

---

## New actions: nap, slip (2026-11-21)

Context: Karol asked for richer, more interesting animations. A first prototype added
generic polish (springs/overlap, breathing, eyes, round hands, squash) and looked worse than
what we have: the figure's strength is crisp pose-to-pose, pictogram-like motion. Direction
changed to new content in the unchanged style. Karol picked three ideas; sketched in a JS
copy of the rig (same joints, bone lengths, IK, easings):
`/Volumes/Lexar SSD/DevCache/EdgeBuddy/sketches/new-actions.html` + `core.js` (serve the
folder over `python3 -m http.server`; poses and timings there are the reference).

Decisions:
- Nap and slip go in; sitting on the edge with dangling legs is dropped. Side view at a
  corner reads as the wheelchair pictogram, and real card corners (16-20 pt) are rounder
  than the 9 pt thigh, so there is nowhere to sit; a front-view sit would put the shins over
  the card face (breaks "nothing plays over the card") and needs foreshortening the rig lacks.
- Both are top-edge actions in the random repertoire, same visual language, no new shapes on
  the figure. Nap's only addition is a "Z" glyph effect beside the head.
- They land before the Android port so its parity fixtures include them.

### Phase 6 — Nap and slip actions
Scope:
1. `FigureAction.nap` (top edge, ~12 s): yawn with arms up and a head roll, kneels, lies down
   on its side along the edge (profile, `lean` 90, arms via limb IK onto the edge), breathes
   slowly (3 cycles of tiny `lean`/`tilt` changes), Z glyphs rise every ~0.9 s while asleep and
   fade out on waking, startles awake (quick head jerk), kneels, stands, shakes the head.
   Z glyphs as a timed effect like `ChampagneSpray` (figure color, mirrored in RTL, part of
   `joints(at:)`-time so pins and fixtures stay pure functions of time).
2. `FigureAction.slip` (top edge): a step in profile, the foot shoots forward (banana-peel),
   the body tips back and drops behind the card, catches the edge with both hands (sag and
   rebound), turns to the front while hidden, a look around while pulled up, then climbs back
   up reusing the climb's hang/steps (`climbHang`/`climbSteps`) and wipes the brow.
3. Repertoire: repeat ranges, weights (nap rarer, it is long), room checks (nap lies along the
   edge: needs its length of room), scroll interrupting mid-nap/mid-hang ends cleanly, pins
   (`holdTime` for a still frame of each), `HumanFigure.actions(at:)`, reduce motion / Low Power.
4. Tests (timeline continuity, still windows: idle CPU ≈ 0 with `loops: false` after both),
   demo Playground picker entries, README/DocC action list, CHANGELOG.

Definition of Done: both actions play from the random repertoire and from pins on the demo,
checked visually in light/dark, LTR/RTL, on a card with 16-20 pt corners; timings match the
sketch; no frame where a limb pokes over the card face; tests green; version bump (minor).
- [x] Discussed
- [x] Researched
- [x] Planned
- [x] Executed
- [x] Committed

---

## Android port (2026-11-20)

Context: EdgeBuddy is iOS/macOS only (SwiftUI, 0.7.0). Question: can it have an Android
equivalent and how. Answer: yes, as a native Kotlin + Jetpack Compose library in the same repo.

Findings:
- The rig is platform-free: `FigureRig.swift`, `FigureProps.swift`, `FigureStageRules.swift`
  (~2.3k lines) import only CoreGraphics/Foundation: poses, keyframes, easing, limb IK,
  action/edge picking. Ports 1:1.
- The SwiftUI layer (~3k lines: stage, anchors, canvas, public API) is redesigned in Compose;
  every API used has a counterpart (table below). "Behind the card" is a per-anchor rect clip
  (`FigureRegionClip`) → `clipRect`.

| iOS | Compose |
|---|---|
| `Canvas` / `GraphicsContext` | `Canvas` / `DrawScope` |
| `TimelineView(.animation)` | `withFrameNanos` loop in `LaunchedEffect` |
| `anchorPreference` + `overlayPreferenceValue` | `Modifier.figureAnchor()` via `onGloballyPositioned` + stage state in a `CompositionLocal` (unregister in `DisposableEffect`, lazy lists) |
| `onScrollPhaseChange` | `NestedScrollConnection` on the stage (any scrollable, incl. `LazyColumn`) |
| `accessibilityReduceMotion`, Low Power, `scenePhase` | `ANIMATOR_DURATION_SCALE == 0`, `PowerManager.isPowerSaveMode`, Lifecycle `RESUMED` |
| `sensoryFeedback`, `layoutDirection`, `dynamicTypeSize` | `LocalHapticFeedback`, `LocalLayoutDirection`, `fontScale` |
| `@Environment(\.figureColor)` etc. | `CompositionLocal` / style parameter |
| `OSSignposter`, Combine, `RandomNumberGenerator` | `androidx.tracing`, coroutines/Flow, seeded `Random` |

Decisions:
- Native Kotlin/Compose port, not KMP (would turn the Swift package into a binary XCFramework,
  lose Swift 6 strictness and SPI, and share only the math), not the Swift SDK for Android
  (per-frame JNI bridge + Swift runtime in the AAR for a decorative widget), not Compose
  Multiplatform (would replace the native SwiftUI version).
- Monorepo: `android/` with a library module `edgebuddy` and a `sample` app; version catalog
  aligned with Nextleg-Android (AGP 9.5, Kotlin 2.4, Compose BOM 2026.09). Compose only; Views
  later via `ComposeView` if ever needed.
- Parity by golden fixtures: a Swift test dumps `FigureTimeline.joints(at:)` samples for every
  action × edge × entrance (+ picker results) to JSON in a shared `fixtures/` folder; Kotlin
  JVM tests compare with tolerance ~1e-6. Both sides use the same seeded PRNG (SplitMix64) so
  random picks are comparable too. A new iOS action fails the Android parity test until ported.
- The `rig` package has no Android imports → fast plain JVM unit tests; the 179 Swift Testing
  tests are ported to JUnit.
- Public API in Compose style: `Modifier.figureAnchor("hero", edges = FigureEdges.All)`,
  `Modifier.figureStage(isWaiting = …)`, `Modifier.peekingFigure()`, `RunningFigure()`,
  custom characters (`FigureCharacter` / `CustomRig` drawing into `DrawScope`).
- Distribution: Maven Central (namespace `io.github.jojogurt`, vanniktech maven-publish; the
  account and GPG key are set up by Karol), JitPack as a quick start. Android versions track
  the iOS version they match feature-wise.
- CI: an Ubuntu job `./gradlew test` (+ sample build), path-filtered to `android/` and `fixtures/`.

### Phase 7 — Android port (Kotlin + Jetpack Compose)
Scope, in order (one phase, these are its steps):
1. Swift side, tests only (no API change): SplitMix64 test generator, fixture export test → `fixtures/*.json` (after Phase 6, so nap and slip are in them).
2. Gradle scaffold in `android/`: library + sample app, version catalog, CI job.
3. Rig port (`FigureJoints`, `FigureTimeline`, IK, props, variation/chain/tap rules, stage rules, anchor picker) + JVM unit tests + parity tests against the fixtures.
4. Drawing: human skeleton → `DrawScope`, `RunningFigure` loader (first visible result in the sample).
5. `Modifier.peekingFigure()` on a single card (top edge, tap, reduce motion, power save, lifecycle).
6. Full stage: anchors (incl. `LazyColumn` add/remove), scroll via nested scroll (incl. nested/horizontal pagers), side routes, chained actions, tap → next card, haptics, `isWaiting`/`loops`/`isEnabled`, pins, RTL, `figureHeight`/color/opacity, per-anchor viewport clip.
7. Custom characters API + demo `Ghost` equivalent; README "Android" section, KDoc.
8. Publishing setup (Maven Central/JitPack), sample app GIF.

Definition of Done: parity tests green against the fixtures for every action/edge/entrance; JVM
+ sample build green in CI; the sample app shows all four iOS demo tabs (Playground, Pinning,
Static, Single card) on an emulator, checked visually in light/dark and RTL; no jank in a
30-card `LazyColumn` scroll (Macrobenchmark or frame metrics), idle CPU ≈ 0 with `loops = false`;
README documents installation and the API; Swift tests still green.

Risks: anchors in lazy lists leaving composition mid-play; nested scrolls (pager in a vertical
list) driving the scroll state; float differences in `acos`/`sin` between platforms (tolerance);
the stage's overlay drawing over app bars (clip to the scroll container's bounds).
- [x] Discussed
- [x] Researched
- [x] Planned
- [ ] Executed
- [ ] Committed

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

---

## Deferred (parking lot)
- Climb down a side (2026-11-09): a descent so a side figure can climb again after reaching the top, or travel both ways in a chained sequence. Options: the climb timeline played in reverse (cheap; check the grip/foot order still reads as climbing, not sliding) vs a dedicated descent animation (looking down, feet first). Would also give a side exit other than the reversed entrance.

- Custom characters: travel under a bottom edge (`travelRoom` is 0 there, kept for the human); a per-action entrance/exit; exposing the stage's heading to `draw` instead of mirroring.
- Phase 5 follow-ups: visual check of the demo on macOS (built only); `HumanFigure.actions(at:)` describes whole plays — consider beats if users build on the human's motion.
- Stage above `NavigationStack`/`TabView`: environment-held anchor registry instead of preferences (cost: per-frame pushes from every anchor; measure first).
- CONTRIBUTING.md, SECURITY.md, issue/PR templates.
- DocC articles (Getting Started, Snapshots, Custom figure).
- Snapshot/regression tests of `FigureCanvas` via `ImageRenderer` + `figurePinned(animated: false)`.
- Reacting to the pointer on macOS/iPad (hide when the cursor comes near, like Peekaboo).
- Community skins gallery (a list of renderers/appearances), never bundling third-party art.
- Naming consistency: `peekingFigure` vs the `figureX` family.

## Completed (collapsed)
- Chained actions in one cycle (2026-11-09): `FigureStyle.actionsPerCycle` (default 1...1), repeats allowed, same edge only, room check per step (no climb in place), scroll ends the run after the action playing, demo picker; pause between actions = next `holdBefore` (no exit → rig skips `holdAfter`) — 297d990
- Fix 0.3.3 — side figure in a pager with content margins and during pull to refresh (2026-11-09): pager bleed (side box) only for the card of the page shown, pager part stored across only; timing tasks signal via `onChange` (stale inputs made it come out mid-scroll or stay parked); reclamp never squashes a climb into one spot (climbing in place) — 3e152bd
- Fix 0.3.2 — side figure jumped when a large title collapsed mid-scroll (2026-11-08): no reclamp for viewport changes while scrolling (title snap-back reports as `decelerating`), region rounded to 1/100 pt (float jitter every frame), demo Pager tab; kept by design: coming out on the visible strip of a card mostly under the bar — 824df9d
- Fix 0.3.1 — anchor in a horizontal pager nested in a vertical ScrollView (2026-11-07): viewport Y from the vertical scroll view, X from the pager; side reclamp deferred to scroll end — 63bfc43
- Phase 3 — Demo + README GIF (2026-11-07): multiplatform demo xcodeproj, 4 tabs, CI build, README GIF — 42222f2
- Phase 4 — Custom figure (2026-11-07): `FigureAppearance` (0ae5505) + `FigureCharacter` protocol (7450c85)
- Phase 5 — Characters with own skeleton and animations (2026-11-07): type-erased stage (0a4051d), public `FigureCharacter`/`HumanFigure` + demo `Ghost` (5057edf), look as `HumanFigure` params, `FigureAppearance` removed, docs (505fa0d). Deviations: `HumanFigure` plays through the unchanged rig and describes its actions as whole plays; `Pose` must be `Equatable` (still windows); extra `figureCharacter(_: any FigureCharacter)` overload.
