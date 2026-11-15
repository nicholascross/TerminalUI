import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct ApplicationDiagnostic: DiagnosticMessage {
    let message: String
    var diagnosticID: MessageID {
        MessageID(domain: "TerminalUI", id: "application")
    }

    var severity: DiagnosticSeverity {
        .error
    }
}

public struct TerminalApplicationMacro: MemberMacro, MemberAttributeMacro, ExtensionMacro {
    public static func expansion(
        of _: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext,
    ) throws -> [AttributeSyntax] {
        guard let declaration = member.asProtocol((any WithAttributesSyntax).self),
            member.is(VariableDeclSyntax.self) || member.is(FunctionDeclSyntax.self) || member.is(InitializerDeclSyntax.self)
        else { return [] }
        guard
            !declaration.attributes.contains(where: {
                guard case .attribute(let attribute) = $0 else { return false }
                return attribute.attributeName.trimmedDescription.split(separator: ".").last == "MainActor"
            }),
            member.asProtocol((any WithModifiersSyntax).self)?.modifiers.contains(where: {
                $0.name.tokenKind == .keyword(.nonisolated)
            }) != true
        else { return [] }
        return ["@MainActor"]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: ApplicationDiagnostic(
                        message: "@TerminalApplication requires a struct with a root conforming to TerminalView",
                    )))
            return []
        }
        guard
            !declaration.memberBlock.members.contains(where: {
                guard let method = $0.decl.as(FunctionDeclSyntax.self) else { return false }
                return method.name.text == "main" && method.modifiers.contains { $0.name.tokenKind == .keyword(.static) }
            })
        else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: ApplicationDiagnostic(
                        message: "@TerminalApplication generates main(); remove the explicit static main method",
                    )))
            return []
        }
        if case .argumentList(let arguments) = node.arguments,
            let argument = arguments.first(where: { $0.label?.text == "arguments" })
        {
            guard let expression = argument.expression.as(MemberAccessExprSyntax.self),
                expression.declName.baseName.text == "self", let type = expression.base
            else {
                context.diagnose(
                    Diagnostic(
                        node: argument,
                        message: ApplicationDiagnostic(
                            message: "Pass an arguments type using .self, for example @TerminalApplication(arguments: Options.self)",
                        )))
                return []
            }
            for member in declaration.memberBlock.members {
                if let property = member.decl.as(VariableDeclSyntax.self),
                    property.bindings.contains(where: {
                        $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "arguments"
                    })
                {
                    context.diagnose(
                        Diagnostic(
                            node: property,
                            message: ApplicationDiagnostic(
                                message: "@TerminalApplication generates arguments; remove the explicit property",
                            )))
                    return []
                }
                if let property = member.decl.as(VariableDeclSyntax.self),
                    property.bindings.contains(where: {
                        $0.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "configuration"
                    })
                {
                    context.diagnose(
                        Diagnostic(
                            node: property,
                            message: ApplicationDiagnostic(
                                message: "Terminal configuration is generated from arguments.terminal; remove the app's configuration property",
                            )))
                    return []
                }
                if let initializer = member.decl.as(InitializerDeclSyntax.self),
                    initializer.signature.parameterClause.parameters.count == 1,
                    initializer.signature.parameterClause.parameters.first?.firstName.text == "arguments"
                {
                    context.diagnose(
                        Diagnostic(
                            node: initializer,
                            message: ApplicationDiagnostic(
                                message: "@TerminalApplication generates init(arguments:); remove the explicit initializer",
                            )))
                    return []
                }
            }
            return [
                "@MainActor private let arguments: \(type)",
                """
                @MainActor
                init(arguments: \(type)) {
                    self.arguments = arguments
                }
                """,
                """
                @MainActor
                public var configuration: TerminalUI.TerminalConfiguration {
                    arguments.terminal.configuration
                }
                """,
                """
                @MainActor
                public static func main() async {
                    await TerminalUIArgumentParser.TerminalArgumentLauncher.run(\(type).self) {
                        Self(arguments: $0)
                    }
                }
                """,
            ]
        }
        return [
            """
            @MainActor
            public static func main() async throws {
                try await Self().makeApplication().run(arguments: CommandLine.arguments)
            }
            """
        ]
    }

    public static func expansion(
        of _: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo _: [TypeSyntax],
        in _: some MacroExpansionContext,
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else { return [] }
        return try [ExtensionDeclSyntax("extension \(type): TerminalUI.TerminalApplicationDefinition {}")]
    }
}
