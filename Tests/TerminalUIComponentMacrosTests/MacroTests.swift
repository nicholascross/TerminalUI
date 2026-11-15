import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import TerminalUIComponentMacroSupport
import XCTest

final class MacroTests: XCTestCase {
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
