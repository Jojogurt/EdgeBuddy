import SwiftUI

extension EnvironmentValues {
    /// Colour of the figure (`figureColor(_:)`).
    @Entry var figureColor: Color = .accentColor
    /// Height of the figure above a top edge, points (`figureHeight(_:)`).
    @Entry var figureHeight: CGFloat = PeekingFigureMetrics.defaultHeight
    /// Opacity of the figure (`figureOpacity(_:)`).
    @Entry var figureOpacity: Double = 1
    /// Selection haptic on tap (`figureHaptics(_:)`).
    @Entry var figureHapticsEnabled: Bool = true
    /// The app's idle-motion decision; nil = the built-in policy
    /// (`figureMotionEnabled(_:)`).
    @Entry var figureMotionOverride: Bool?
}

extension View {
    /// Sets the colour of every figure in this view hierarchy.
    ///
    /// The figure is drawn in a single colour. Pass a dynamic colour (an
    /// asset colour, or one that resolves per colour scheme) to follow light
    /// and dark mode. Defaults to `Color.accentColor`.
    ///
    /// - Parameter color: the figure's colour.
    public func figureColor(_ color: Color) -> some View {
        environment(\.figureColor, color)
    }

    /// Sets the opacity of every figure in this view hierarchy, 0…1 —
    /// say 0.8 to let it sit a little softer on the cards. Defaults to 1.
    ///
    /// - Parameter opacity: the figure's opacity, clamped to 0…1.
    public func figureOpacity(_ opacity: Double) -> some View {
        environment(\.figureOpacity, min(max(opacity, 0), 1))
    }

    /// Sets the figure's size for this view hierarchy: its height above a
    /// top edge, in points, from the feet on the edge to the head with room
    /// for jumps. Defaults to 56. The other measures (width, margins, the
    /// footprint at the bottom and the sides, the narrowest anchor it uses)
    /// scale with it.
    ///
    /// - Parameter height: the figure's height in points; values below 16
    ///   are raised to 16.
    public func figureHeight(_ height: CGFloat) -> some View {
        environment(\.figureHeight, height)
    }

    /// Turns the selection haptic played when the figure is tapped on or
    /// off for this view hierarchy. On by default. The system already
    /// silences it when haptics are off in Settings.
    ///
    /// - Parameter enabled: false = no haptic on tap.
    public func figureHaptics(_ enabled: Bool) -> some View {
        environment(\.figureHapticsEnabled, enabled)
    }

    /// Overrides when the figure may loop (come out again and again).
    ///
    /// By default the stage decides on its own: looping runs only while the
    /// scene is active, Reduce Motion is off and Low Power Mode is off.
    /// Pass your app's own idle-motion decision to replace that policy, or
    /// nil to go back to the built-in one. Whatever you pass, the figure
    /// never loops under Reduce Motion or in Low Power Mode, and without
    /// looping it still comes out once and stands.
    ///
    /// - Parameter enabled: true = may loop, false = comes out once and
    ///   stands, nil = the built-in policy.
    public func figureMotionEnabled(_ enabled: Bool?) -> some View {
        environment(\.figureMotionOverride, enabled)
    }
}
