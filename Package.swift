// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "TerminalUI",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(name: "TerminalUI", targets: ["TerminalUI"]),
        .library(name: "TerminalUILayout", targets: ["TerminalUILayout"]),
        .library(name: "TerminalUIChroma", targets: ["TerminalUIChroma"]),
        .executable(name: "RepositoryDemo", targets: ["RepositoryDemo"]),
        .executable(name: "LayoutDemo", targets: ["LayoutDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Chroma.git", from: "0.3.1"),
    ],
    targets: [
        .target(name: "CTerminalSupport", publicHeadersPath: "include"),
        .target(name: "TerminalUICore"),
        .target(name: "TerminalUIText", dependencies: ["TerminalUICore"]),
        .target(name: "TerminalUIInput", dependencies: ["TerminalUICore"]),
        .target(name: "TerminalUILayoutEngine", dependencies: ["TerminalUICore", "TerminalUIText"]),
        .target(name: "TerminalUIInteraction", dependencies: ["TerminalUICore", "TerminalUIText", "TerminalUILayoutEngine"]),
        .target(name: "TerminalUIRendering", dependencies: ["TerminalUICore", "TerminalUIText", "TerminalUILayoutEngine", "TerminalUIInteraction"]),
        .target(name: "TerminalUIRuntime", dependencies: ["TerminalUICore", "TerminalUIInput", "TerminalUIRendering", "CTerminalSupport"]),
        .target(name: "TerminalUI", dependencies: ["TerminalUICore", "TerminalUIInput", "TerminalUIRendering", "TerminalUIRuntime"]),
        .target(name: "TerminalUILayout", dependencies: ["TerminalUI", "TerminalUICore"]),
        .target(name: "TerminalUIChroma", dependencies: ["TerminalUI", .product(name: "Chroma", package: "Chroma")]),
        .executableTarget(name: "RepositoryDemo", dependencies: ["TerminalUI", "TerminalUIChroma"], path: "Examples/RepositoryDemo"),
        .executableTarget(name: "LayoutDemo", dependencies: ["TerminalUILayout"], path: "Examples/LayoutDemo"),
        .testTarget(name: "TerminalUILayoutTests", dependencies: ["TerminalUILayout"]),
        .testTarget(name: "LayoutDemoTests", dependencies: ["LayoutDemo", "TerminalUILayout"]),
        .testTarget(name: "RepositoryDemoTests", dependencies: ["RepositoryDemo"]),
        .testTarget(
            name: "TerminalUITests",
            dependencies: [
                "TerminalUI",
                "TerminalUIText",
                "TerminalUILayoutEngine",
                "TerminalUIInteraction",
                "TerminalUIRendering",
                "TerminalUIRuntime",
                "CTerminalSupport",
            ],
        ),
        .testTarget(name: "TerminalUIInputTests", dependencies: ["TerminalUICore", "TerminalUIInput"]),
        .testTarget(name: "TerminalUIInteractionTests", dependencies: ["TerminalUIInteraction"]),
        .testTarget(name: "TerminalUIRuntimeTests", dependencies: ["TerminalUICore", "TerminalUIRendering", "TerminalUIRuntime"]),
        .testTarget(name: "TerminalUICompatibilityTests", dependencies: ["TerminalUI"]),
        .testTarget(name: "TerminalUIChromaTests", dependencies: ["TerminalUIChroma", "TerminalUI"]),
    ],
    swiftLanguageModes: [.v6],
)
