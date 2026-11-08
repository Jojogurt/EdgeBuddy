import SwiftUI

/// EdgeBuddy demo: five tabs, one per way to use the package.
@main
struct EdgeBuddyDemoApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Playground", systemImage: "slider.horizontal.3") { PlaygroundTab() }
                Tab("Pinning", systemImage: "pin") { PinningTab() }
                Tab("Static", systemImage: "rectangle.grid.1x2") { StaticTab() }
                Tab("Single card", systemImage: "rectangle") { SingleCardTab() }
                Tab("Pager", systemImage: "rectangle.split.3x1") { PagerTab() }
            }
        }
    }
}
