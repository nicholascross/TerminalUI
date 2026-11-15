import SwiftSyntax
import SwiftSyntaxMacros
import TerminalUIComponentMacroSupport

public struct TerminalApplicationMacro: MemberMacro, MemberAttributeMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext,
    ) throws -> [AttributeSyntax] {
        try TerminalUIComponentMacroSupport.TerminalApplicationMacro.expansion(
            of: node, attachedTo: declaration, providingAttributesFor: member, in: context,
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        try TerminalUIComponentMacroSupport.TerminalApplicationMacro.expansion(
            of: node, providingMembersOf: declaration, conformingTo: protocols, in: context,
        )
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [ExtensionDeclSyntax] {
        try TerminalUIComponentMacroSupport.TerminalApplicationMacro.expansion(
            of: node, attachedTo: declaration, providingExtensionsOf: type, conformingTo: protocols, in: context,
        )
    }
}
