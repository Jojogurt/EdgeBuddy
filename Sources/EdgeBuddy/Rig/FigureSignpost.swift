import os

/// `os_signpost` intervals (Points of Interest) around the hot paths, for
/// Instruments. Near-zero cost while nothing records them.
enum FigureSignpost {
    static let signposter = OSSignposter(subsystem: "EdgeBuddy", category: .pointsOfInterest)

    /// Runs `body` inside a signpost interval called `name`.
    @inline(__always)
    static func interval<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try body()
    }
}
