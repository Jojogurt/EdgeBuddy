import Combine
import SwiftUI

/// A marked view the figure may come out from behind (`figureAnchor`).
struct FigureAnchorItem {
    let id: AnyHashable
    let edges: FigureEdges
    let bounds: Anchor<CGRect>
    /// Visible area of the scroll view the view sits in, in global space;
    /// nil = not in a scroll view (or not measured yet).
    var region: CGRect?
}

/// A marked view resolved into the stage's space.
struct FigureAnchorFrame: Equatable {
    let id: AnyHashable
    let edges: FigureEdges
    let rect: CGRect
    /// The part of the stage this anchor's scroll view shows (between its
    /// bars), in the stage's space; nil = the stage's own viewport.
    var viewport: CGRect?
}

/// Collects the marked views under a stage, in layout order.
struct FigureAnchorsKey: PreferenceKey {
    static var defaultValue: [FigureAnchorItem] { [] }

    static func reduce(value: inout [FigureAnchorItem], nextValue: () -> [FigureAnchorItem]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Marks this view as a place the screen's figure (`figureStage`) may
    /// come out from behind. Any view works — usually a card at least
    /// ~110 pt wide. Takes no space and changes nothing without a stage.
    ///
    /// - Parameters:
    ///   - id: unique among the stage's anchors (also across segments).
    ///   - edges: edges the figure may come out at: stands on the top, hangs
    ///     under the bottom, peeks / flags / climbs at the sides. Each is used
    ///     only while the figure fits there and that part is on screen.
    public func figureAnchor(_ id: some Hashable, edges: FigureEdges = .top) -> some View {
        modifier(FigureAnchorModifier(id: AnyHashable(id), edges: edges))
    }

    /// One small figure for the whole screen, put on the screen's
    /// `ScrollView`: each cycle it comes out from behind another marked view
    /// (`figureAnchor(_:edges:)`) that is fully on screen — never the same
    /// one twice in a row when there is another — plays a random action,
    /// goes back and comes out elsewhere. A tap moves it too. It rides along
    /// while the content scrolls and waits for the scroll to stop before
    /// coming out.
    ///
    /// It stands over whatever is above the anchor (its feet on the anchor's
    /// edge, the rest hidden behind it) and is clipped, per anchor, to the
    /// visible area of the scroll view that anchor sits in — between its
    /// navigation and tab bars. Decoration only — hidden from VoiceOver and at
    /// accessibility text sizes.
    ///
    /// The stage can sit on the `ScrollView` itself or on any view that
    /// contains one or several scroll views (a screen's `body`, a `VStack`
    /// with a header and a list, columns side by side). It must be *inside*
    /// a `NavigationStack` page or `TabView` tab, not above them — SwiftUI
    /// does not pass the anchors out of those containers. Sheets, popovers
    /// and pushed screens are separate hierarchies and need their own stage;
    /// a view drawn over a card (other than the bars) is not detected —
    /// use `isWaiting` while a modal is up.
    ///
    /// Tune it with `figureColor(_:)`, `figureOpacity(_:)`, `figureHeight(_:)`,
    /// `figureHaptics(_:)` and `figureMotionEnabled(_:)`; pick who plays with
    /// `figureCharacter(_:)` (``HumanFigure`` by default).
    ///
    /// - Parameters:
    ///   - isEnabled: false = no figure.
    ///   - style: entrance, tempo and the first entrance's delay.
    ///   - isWaiting: true while something else holds the stage (say a
    ///     celebration); the figure stays where it is (or behind its card)
    ///     and carries on once it ends.
    ///   - loops: true = it never settles (only while idle motion is
    ///     allowed, see `figureMotionEnabled(_:)`); otherwise it comes out
    ///     once and stands.
    public func figureStage(
        isEnabled: Bool = true, style: FigureStyle = .standard, isWaiting: Bool = false, loops: Bool = true
    ) -> some View {
        modifier(FigureStageModifier(
            isEnabled: isEnabled, style: style, isWaiting: isWaiting, loops: loops, isBounded: true
        ))
    }

    /// A figure coming out from behind this view's top edge only — a stage
    /// with this single anchor, not bounded by the screen. For one-off cards
    /// (onboarding, empty states); screens with several cards use
    /// `figureStage(isEnabled:style:isWaiting:loops:)` +
    /// `figureAnchor(_:edges:)`. It takes no space: put the card after the
    /// content above it, and leave room (or `scrollClipDisabled()`) where the
    /// card is first in a scroll view.
    ///
    /// - Parameters:
    ///   - isEnabled: false = no figure.
    ///   - style: entrance, tempo and the first entrance's delay.
    ///   - isWaiting: true while something else holds the stage; the figure
    ///     waits and carries on once it ends.
    ///   - loops: true = it never settles (only while idle motion is
    ///     allowed); otherwise it comes out once and stands.
    public func peekingFigure(
        isEnabled: Bool = true, style: FigureStyle = .standard, isWaiting: Bool = false, loops: Bool = true
    ) -> some View {
        figureAnchor(SoloAnchor.id)
            .modifier(FigureStageModifier(
                isEnabled: isEnabled, style: style, isWaiting: isWaiting, loops: loops, isBounded: false
            ))
    }
}

/// Marks a view and measures the visible area of the scroll view around it.
private struct FigureAnchorModifier: ViewModifier {
    let id: AnyHashable
    let edges: FigureEdges
    @State private var region: CGRect?

    func body(content: Content) -> some View {
        content
            // The visible area of the scroll views around it, in global space:
            // Y from the closest vertical one, X from the closest horizontal one
            // (a pager inside the screen's scroll view). Neither moves while its
            // own content scrolls, so this fires only on layout.
            .onGeometryChange(for: CGRect?.self) { proxy in
                FigureViewport.region(
                    vertical: proxy.bounds(of: .scrollView(axis: .vertical)),
                    horizontal: proxy.bounds(of: .scrollView(axis: .horizontal)),
                    origin: proxy.frame(in: .global).origin
                )
            } action: { region = $0 }
            .anchorPreference(key: FigureAnchorsKey.self, value: .bounds) {
                [FigureAnchorItem(id: id, edges: edges, bounds: $0, region: region)]
            }
    }
}

/// The single anchor of `peekingFigure` (`FigurePin.singleCard`).
enum SoloAnchor: Hashable, Sendable {
    case id
}

/// The built-in idle-motion policy: loops run only for an active scene,
/// with Reduce Motion and Low Power Mode off.
enum FigureMotionPolicy {
    static func idleEnabled(reduceMotion: Bool, lowPowerMode: Bool, scenePhase: ScenePhase) -> Bool {
        !reduceMotion && !lowPowerMode && scenePhase == .active
    }
}

/// How many scroll views are scrolling right now: each reports its own
/// transitions through the one closure, so they are counted.
struct FigureScrollTracker: Equatable {
    private(set) var count = 0
    var isScrolling: Bool { count > 0 }

    mutating func phaseChanged(from old: Bool, to new: Bool) {
        guard old != new else { return }
        count = max(0, count + (new ? 1 : -1))
    }
}

enum FigureViewport {
    /// The visible area around an anchor, in global space, from the bounds of
    /// the closest vertical and horizontal scroll views (each in the anchor's
    /// local space; `origin` = the anchor's global origin). Y comes from the
    /// vertical one — not from a horizontal pager nested in it, which moves
    /// with the vertical scroll and is only about as tall as its cards — and X
    /// from both (the pager cuts off the cards of other pages). One alone is
    /// used as it is; none = nil (not in a scroll view).
    static func region(vertical: CGRect?, horizontal: CGRect?, origin: CGPoint) -> CGRect? {
        let global = { (rect: CGRect) in rect.offsetBy(dx: origin.x, dy: origin.y) }
        switch (vertical.map(global), horizontal.map(global)) {
        case (nil, nil):
            return nil
        case let (vertical?, nil):
            return vertical
        case let (nil, horizontal?):
            return horizontal
        case let (vertical?, horizontal?):
            let minX = max(vertical.minX, horizontal.minX)
            let maxX = min(vertical.maxX, horizontal.maxX)
            return CGRect(x: minX, y: vertical.minY, width: max(0, maxX - minX), height: vertical.height)
        }
    }

    /// The stage's visible area for an anchor: the scroll view's `region`
    /// (global space; `origin` = the stage's global origin) inside the stage.
    /// nil region = the whole stage. A region outside the stage is empty.
    static func resolve(stage: CGRect, region: CGRect?, origin: CGPoint) -> CGRect {
        guard let region else { return stage }
        let local = region.offsetBy(dx: -origin.x, dy: -origin.y)
        let visible = local.intersection(stage)
        return visible.isNull ? CGRect(origin: local.origin, size: .zero) : visible
    }
}

private struct FigureStageModifier: ViewModifier {
    let isEnabled: Bool
    let style: FigureStyle
    let isWaiting: Bool
    let loops: Bool
    /// The stage is the visible area of a scroll view (clipped, anchors must
    /// be fully inside); false = a single card, no bounds.
    let isBounded: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.figureColor) private var color
    @Environment(\.figureOpacity) private var opacity
    @Environment(\.figureHeight) private var height
    @Environment(\.figureHapticsEnabled) private var hapticsEnabled
    @Environment(\.figureMotionOverride) private var motionOverride
    @Environment(\.figurePin) private var pin
    @Environment(\.figureCharacter) private var characterOverride
    @State private var scrolling = FigureScrollTracker()
    @State private var tapTick = 0
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// The app's decision when it gave one, else the built-in policy.
    private var idleMotionEnabled: Bool {
        motionOverride ?? FigureMotionPolicy.idleEnabled(
            reduceMotion: reduceMotion, lowPowerMode: lowPowerMode, scenePhase: scenePhase
        )
    }

    func body(content: Content) -> some View {
        content
            // Every scroll view below reports here (through bars and tabs too).
            .onScrollPhaseChange { old, new in scrolling.phaseChanged(from: old.isScrolling, to: new.isScrolling) }
            .overlayPreferenceValue(FigureAnchorsKey.self) { items in
                if isEnabled, PeekingFigureMetrics.isShown(dynamicTypeSize: dynamicTypeSize) {
                    let character = characterOverride ?? HumanRig.character()
                    GeometryReader { proxy in
                        let origin = proxy.frame(in: .global).origin
                        let stage = CGRect(origin: .zero, size: proxy.size)
                        PeekingFigureView(
                            anchors: items.map {
                                FigureAnchorFrame(
                                    id: $0.id, edges: $0.edges.physical(for: layoutDirection), rect: proxy[$0.bounds],
                                    viewport: isBounded
                                        ? FigureViewport.resolve(stage: stage, region: $0.region, origin: origin) : nil
                                )
                            },
                            viewport: isBounded ? stage : nil,
                            isScrolling: scrolling.isScrolling,
                            style: style,
                            isWaiting: isWaiting,
                            loops: loops,
                            color: color,
                            character: character,
                            metrics: PeekingFigureMetrics(height: height, geometry: character.geometry),
                            idleMotionEnabled: idleMotionEnabled,
                            lowPowerMode: lowPowerMode,
                            pin: pin?.physical(for: layoutDirection),
                            onTap: { tapTick += 1 }
                        )
                    }
                    .opacity(opacity)
                    // Bounded: never over the bars. Unbounded: stands above the card.
                    .clipShape(Rectangle().inset(by: isBounded ? 0 : -10_000))
                }
            }
            // Anchors under this stage belong to it, not to an outer one.
            .transformPreference(FigureAnchorsKey.self) { $0 = [] }
            .sensoryFeedback(trigger: tapTick) { _, _ in hapticsEnabled ? .selection : nil }
            // Posted on an arbitrary thread — hop to main before touching state.
            .onReceive(
                NotificationCenter.default
                    .publisher(for: .NSProcessInfoPowerStateDidChange)
                    .receive(on: DispatchQueue.main)
            ) { _ in
                lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
    }
}
