import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct ComponentDiagnostic: DiagnosticMessage {
    let message: String
    var diagnosticID: MessageID {
        MessageID(domain: "TerminalUIComponents", id: "state")
    }

    var severity: DiagnosticSeverity {
        .error
    }
}

public struct TerminalComponentMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo _: [TypeSyntax],
        in context: some MacroExpansionContext,
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: node,
                message: ComponentDiagnostic(message: "@TerminalComponent requires a struct conforming to TerminalView"),
            ))
            return []
        }
        var statements: [String] = []
        for member in declaration.memberBlock.members {
            guard let property = member.decl.as(VariableDeclSyntax.self), property.attributes.contains(where: {
                guard case let .attribute(attribute) = $0 else { return false }
                return attribute.attributeName.trimmedDescription.split(separator: ".").last == "State"
            }) else { continue }
            guard property.bindingSpecifier.tokenKind == .keyword(.var),
                  !property.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }),
                  property.bindings.count == 1,
                  let binding = property.bindings.first,
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                context.diagnose(Diagnostic(node: property, message: ComponentDiagnostic(message: "@State requires a single stored instance var")))
                continue
            }
            let name = String(identifier.identifier.text.filter { $0 != "`" })
            statements.append("self._\(name)._install(in: installation, key: \"\(name)\")")
        }
        return [DeclSyntax(stringLiteral: """
        public mutating func _installState(_ installation: StateInstallation) {
            \(statements.joined(separator: "\n"))
        }
        """)]
    }
}
