import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import TerminalUIComponentMacroSupport
import XCTest

final class MacroTests: XCTestCase {
    func testArgumentApplicationSynthesizesStorageInitializerAndTypedLauncher() {
        assertMacroExpansion("""
        @main
        @TerminalApplication(arguments: Settings.Options.self)
        struct Demo {
            var root: some TerminalView { Screen(path: arguments.path) }
        }
        """, expandedSource: """
        @main
        struct Demo {
            @MainActor
            var root: some TerminalView { Screen(path: arguments.path) }

            @MainActor private let arguments: Settings.Options

            @MainActor
            init(arguments: Settings.Options) {
                self.arguments = arguments
            }

            @MainActor
            public var configuration: TerminalUI.TerminalConfiguration {
                arguments.terminal.configuration
            }

            @MainActor
            public static func main() async {
                await TerminalUIArgumentParser.TerminalArgumentLauncher.run(Settings.Options.self) {
                    Self(arguments: $0)
                }
            }
        }

        extension Demo: TerminalUI.TerminalApplicationDefinition {
        }
        """, macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testArgumentApplicationRejectsDuplicateStorage() {
        assertMacroExpansion("""
        @TerminalApplication(arguments: Options.self)
        struct Demo {
            let arguments: Options
        }
        """, expandedSource: """
        struct Demo {
            @MainActor
            let arguments: Options
        }

        extension Demo: TerminalUI.TerminalApplicationDefinition {
        }
        """, diagnostics: [DiagnosticSpec(
            message: "@TerminalApplication generates arguments; remove the explicit property",
            line: 3, column: 5
        )], macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testArgumentApplicationRejectsDuplicateInitializer() {
        assertMacroExpansion("""
        @TerminalApplication(arguments: Options.self)
        struct Demo {
            init(arguments: Options) {}
        }
        """, expandedSource: """
        struct Demo {
            @MainActor
            init(arguments: Options) {}
        }

        extension Demo: TerminalUI.TerminalApplicationDefinition {
        }
        """, diagnostics: [DiagnosticSpec(
            message: "@TerminalApplication generates init(arguments:); remove the explicit initializer",
            line: 3, column: 5
        )], macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testArgumentApplicationRejectsASecondConfigurationSource() {
        assertMacroExpansion("""
        @TerminalApplication(arguments: Options.self)
        struct Demo {
            var configuration: TerminalConfiguration { .init(mouseEnabled: false) }
        }
        """, expandedSource: """
        struct Demo {
            @MainActor
            var configuration: TerminalConfiguration { .init(mouseEnabled: false) }
        }

        extension Demo: TerminalUI.TerminalApplicationDefinition {
        }
        """, diagnostics: [DiagnosticSpec(
            message: "Terminal configuration is generated from arguments.terminal; remove the app's configuration property",
            line: 3, column: 5
        )], macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testArgumentApplicationRequiresAMetatypeLiteral() {
        assertMacroExpansion("""
        @TerminalApplication(arguments: optionsType)
        struct Demo {}
        """, expandedSource: """
        struct Demo {}

        extension Demo: TerminalUI.TerminalApplicationDefinition {
        }
        """, diagnostics: [DiagnosticSpec(
            message: "Pass an arguments type using .self, for example @TerminalApplication(arguments: Options.self)",
            line: 1, column: 22
        )], macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testApplicationEntryPoint() {
        assertMacroExpansion("""
        @main
        @TerminalApplication
        struct Demo {
            var root: some TerminalView { Screen() }
        }
        """, expandedSource: """
        @main
        struct Demo {
            @MainActor
            var root: some TerminalView { Screen() }

            @MainActor
            public static func main() async throws {
                try await Self().makeApplication().run(arguments: CommandLine.arguments)
            }
        }

        extension Demo: TerminalUI.TerminalApplicationDefinition {
        }
        """, macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testRejectsReferenceApplications() {
        assertMacroExpansion("""
        @TerminalApplication
        class Demo {}
        """, expandedSource: """
        class Demo {}
        """, diagnostics: [DiagnosticSpec(
            message: "@TerminalApplication requires a struct with a root conforming to TerminalView",
            line: 1, column: 1,
        )], macros: ["TerminalApplication": TerminalApplicationMacro.self])
    }

    func testPrivateApplicationContextRegistration() {
        assertMacroExpansion("""
        @TerminalComponent
        struct Screen: TerminalView {
            @ApplicationContext private var application
            var body: Element { Button("Quit", id: "quit").onActivate { application.stop() } }
        }
        """, expandedSource: """
        struct Screen: TerminalView {
            @ApplicationContext private var application
            var body: Element { Button("Quit", id: "quit").onActivate { application.stop() } }

            public mutating func _installState(_ installation: StateInstallation) {
                self._application._install(in: installation, key: "application")
            }
        }
        """, macros: ["TerminalComponent": TerminalComponentMacro.self])
    }

    func testPrivateStateRegistration() {
        assertMacroExpansion("""
        @TerminalComponent
        struct Command: TerminalView {
            @State private var draft = ""
            @State private var selection: String? = nil
            var body: Element { Text(draft) }
        }
        """, expandedSource: """
        struct Command: TerminalView {
            @State private var draft = ""
            @State private var selection: String? = nil
            var body: Element { Text(draft) }

            public mutating func _installState(_ installation: StateInstallation) {
                self._draft._install(in: installation, key: "draft")
                self._selection._install(in: installation, key: "selection")
            }
        }
        """, macros: ["TerminalComponent": TerminalComponentMacro.self])
    }

    func testRejectsReferenceComponents() {
        assertMacroExpansion("""
                             @TerminalComponent
                             class Command {}
                             """, expandedSource: """
                             class Command {}
                             """, diagnostics: [DiagnosticSpec(
                                 message: "@TerminalComponent requires a struct conforming to TerminalView",
                                 line: 1,
                                 column: 1,
                             )],
                             macros: ["TerminalComponent": TerminalComponentMacro.self])
    }
}
