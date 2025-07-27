// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "TerminalUI",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "TerminalUI",
            targets: ["TerminalUI"]
        ),
    ],
    targets: [
        .target(
            name: "TerminalUI",
            path: "Sources/TerminalUI"
        ),
        .executableTarget(
            name: "TerminalUIExample",
            dependencies: ["TerminalUI"],
            path: "Examples/TerminalUIExample"
        ),
        .testTarget(
            name: "TerminalUITests",
            dependencies: ["TerminalUI"],
            path: "Tests/TerminalUITests"
        ),
    ]
)
