import Combine
import SwiftUI

/// A marked view the figure may come out from behind (`figureAnchor`).
struct FigureAnchorItem {
    let id: AnyHashable
    let edges: FigureEdges
    let bounds: Anchor<CGRect>
}

/// A marked view resolved into the stage's space.
struct FigureAnchorFrame: Equatable {
    let id: AnyHashable
    let edges: FigureEdges
    let rect: CGRect
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
        anchorPreference(key: FigureAnchorsKey.self, value: .bounds) {
            [FigureAnchorItem(id: AnyHashable(id), edges: edges, bounds: $0)]
        }
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
    /// edge, the rest hidden behind it) and is clipped to the visible area
    /// between the bars. Decoration only — hidden from VoiceOver and at
    /// accessibility text sizes.
    ///
    /// Tune it with `figureColor(_:)`, `figureOpacity(_:)`, `figureHeight(_:)`,
    /// `figureHaptics(_:)` and `figureMotionEnabled(_:)`.
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
    @State private var isScrolling = false
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
            .onScrollPhaseChange { _, phase in
                if phase.isScrolling != isScrolling { isScrolling = phase.isScrolling }
            }
            .overlayPreferenceValue(FigureAnchorsKey.self) { items in
                if isEnabled, PeekingFigureMetrics.isShown(dynamicTypeSize: dynamicTypeSize) {
                    GeometryReader { proxy in
                        PeekingFigureView(
                            anchors: items.map {
                                FigureAnchorFrame(
                                    id: $0.id, edges: $0.edges.physical(for: layoutDirection), rect: proxy[$0.bounds]
                                )
                            },
                            viewport: isBounded ? CGRect(origin: .zero, size: proxy.size) : nil,
                            isScrolling: isScrolling,
                            style: style,
                            isWaiting: isWaiting,
                            loops: loops,
                            color: color,
                            metrics: PeekingFigureMetrics(height: height),
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
