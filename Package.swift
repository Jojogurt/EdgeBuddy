// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EdgeBuddy",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "EdgeBuddy", targets: ["EdgeBuddy"]),
    ],
    targets: [
        .target(name: "EdgeBuddy"),
        .testTarget(name: "EdgeBuddyTests", dependencies: ["EdgeBuddy"]),
    ],
    swiftLanguageModes: [.v6]
)
