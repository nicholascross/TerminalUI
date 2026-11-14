import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import TerminalUIComponentMacroSupport
import XCTest

final class MacroTests: XCTestCase {
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
