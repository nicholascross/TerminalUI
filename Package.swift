// swift-tools-version: 6.3

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "TerminalUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v15),
    ],
    products: [
        .library(name: "TerminalUI", targets: ["TerminalUI"]),
        .library(name: "TerminalUIArgumentParser", targets: ["TerminalUIArgumentParser"]),
        .library(name: "TerminalUIEngine", targets: ["TerminalUIEngine"]),
        .library(name: "TerminalUIBridge", targets: ["TerminalUIBridge"]),
        .library(name: "TerminalUIChroma", targets: ["TerminalUIChroma"]),
        .executable(name: "RepositoryDemo", targets: ["RepositoryDemo"]),
        .executable(name: "LayoutDemo", targets: ["LayoutDemo"]),
        .executable(name: "EngineDemo", targets: ["EngineDemo"]),
        .executable(name: "HighlightedScrollDemo", targets: ["HighlightedScrollDemo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Chroma.git", from: "0.3.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
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
        .target(name: "TerminalUIEngine", dependencies: ["TerminalUICore", "TerminalUIInput", "TerminalUIRendering", "TerminalUIRuntime"]),
        .target(name: "TerminalUIBridge", dependencies: ["TerminalUI", "TerminalUIEngine", "TerminalUICore"]),
        .target(name: "TerminalUIComponentRuntime", dependencies: ["TerminalUICore"]),
        .target(name: "TerminalUIComponentMacroSupport", dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        ]),
        .macro(name: "TerminalUIComponentMacros", dependencies: [
            "TerminalUIComponentMacroSupport",
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        .target(name: "TerminalUI", dependencies: [
            "TerminalUICore", "TerminalUIRuntime", "TerminalUIComponentRuntime", "TerminalUIComponentMacros",
        ]),
        .target(name: "TerminalUIChroma", dependencies: ["TerminalUICore", .product(name: "Chroma", package: "Chroma")]),
        .target(name: "TerminalUIArgumentParser", dependencies: [
            "TerminalUI", "TerminalUIComponentMacros", .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .target(name: "RepositoryDemoSupport", dependencies: ["TerminalUI"], path: "Examples/RepositoryDemo/Support"),
        .executableTarget(name: "RepositoryDemo", dependencies: [
            "RepositoryDemoSupport", "TerminalUI", "TerminalUIArgumentParser",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ], path: "Examples/RepositoryDemo/App"),
        .target(name: "LayoutDemoSupport", dependencies: ["TerminalUI"], path: "Examples/LayoutDemo/Support"),
        .executableTarget(name: "LayoutDemo", dependencies: ["LayoutDemoSupport", "TerminalUI"], path: "Examples/LayoutDemo/App"),
        .executableTarget(name: "EngineDemo", dependencies: ["TerminalUIEngine"], path: "Examples/EngineDemo", exclude: ["README.md"]),
        .executableTarget(
            name: "HighlightedScrollDemo",
            dependencies: ["TerminalUIChroma", "TerminalUIEngine"],
            path: "Examples/HighlightedScrollDemo",
            exclude: ["README.md"],
        ),
        .testTarget(name: "TerminalUIComponentRuntimeTests", dependencies: ["TerminalUIComponentRuntime"]),
        .testTarget(name: "TerminalUIComponentsTests", dependencies: ["TerminalUI", "TerminalUIEngine", "TerminalUIBridge", "TerminalUIRuntime", "TerminalUILayoutEngine"]),
        .testTarget(name: "TerminalUIComponentMacrosTests", dependencies: ["TerminalUIComponentMacroSupport", .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")]),
        .testTarget(name: "TerminalUILayoutTests", dependencies: ["TerminalUIEngine"]),
        .testTarget(name: "LayoutDemoTests", dependencies: ["LayoutDemoSupport", "TerminalUI"]),
        .testTarget(name: "RepositoryDemoTests", dependencies: ["RepositoryDemoSupport", "TerminalUI"]),
        .testTarget(name: "TerminalUIArgumentParserTests", dependencies: [
            "TerminalUIArgumentParser", "TerminalUI", .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(
            name: "TerminalUITests",
            dependencies: [
                "TerminalUIEngine",
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
        .testTarget(name: "TerminalUICompatibilityTests", dependencies: ["TerminalUIEngine"]),
        .testTarget(name: "TerminalUIChromaTests", dependencies: ["TerminalUIChroma", "TerminalUIEngine"]),
    ],
    swiftLanguageModes: [.v6],
)
