import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxMacros
import TerminalUIComponentMacroSupport

public struct TerminalComponentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        try TerminalUIComponentMacroSupport.TerminalComponentMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context,
        )
    }
}

@main
struct TerminalUIComponentPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [TerminalComponentMacro.self, TerminalApplicationMacro.self]
}
