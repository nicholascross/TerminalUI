// swift-tools-version: 6.3

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "TerminalUI",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(name: "TerminalUI", targets: ["TerminalUI"]),
        .library(name: "TerminalUILayout", targets: ["TerminalUILayout"]),
        .library(name: "TerminalUIComponents", targets: ["TerminalUIComponents"]),
        .library(name: "TerminalUIChroma", targets: ["TerminalUIChroma"]),
        .executable(name: "RepositoryDemo", targets: ["RepositoryDemo"]),
        .executable(name: "LayoutDemo", targets: ["LayoutDemo"]),
        .executable(name: "ComponentConsumer", targets: ["ComponentConsumer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onevcat/Chroma.git", from: "0.3.1"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "603.0.0"),
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
        .target(name: "TerminalUIComponents", dependencies: [
            "TerminalUICore", "TerminalUIRuntime", "TerminalUILayout", "TerminalUIComponentRuntime", "TerminalUIComponentMacros",
        ]),
        .target(name: "TerminalUIChroma", dependencies: ["TerminalUI", .product(name: "Chroma", package: "Chroma")]),
        .executableTarget(name: "RepositoryDemo", dependencies: ["TerminalUI", "TerminalUIChroma"], path: "Examples/RepositoryDemo"),
        .target(name: "LayoutDemoSupport", dependencies: ["TerminalUIComponents"], path: "Examples/LayoutDemo"),
        .executableTarget(name: "LayoutDemo", dependencies: ["LayoutDemoSupport", "TerminalUIComponents"], path: "Examples/LayoutDemoRunner"),
        .executableTarget(name: "ComponentConsumer", dependencies: ["TerminalUIComponents"], path: "Examples/ComponentConsumer"),
        .testTarget(name: "TerminalUIComponentRuntimeTests", dependencies: ["TerminalUIComponentRuntime"]),
        .testTarget(name: "TerminalUIComponentsTests", dependencies: ["TerminalUIComponents", "TerminalUIRuntime", "TerminalUILayoutEngine"]),
        .testTarget(name: "TerminalUIComponentMacrosTests", dependencies: ["TerminalUIComponentMacroSupport", .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")]),
        .testTarget(name: "TerminalUILayoutTests", dependencies: ["TerminalUILayout"]),
        .testTarget(name: "LayoutDemoTests", dependencies: ["LayoutDemoSupport", "TerminalUIComponents", "TerminalUIRuntime"]),
        .testTarget(name: "RepositoryDemoTests", dependencies: ["RepositoryDemo", "TerminalUI"]),
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
