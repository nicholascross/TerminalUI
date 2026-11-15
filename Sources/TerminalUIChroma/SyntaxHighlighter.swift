import Chroma
import Foundation
import TerminalUICore

/// Converts Chroma tokens into semantic spans rendered by TerminalUI.
public final class SyntaxHighlighter {
    private let highlighter = Highlighter()

    public init() {}

    /// A nil language produces plain text. Unknown languages throw Chroma's language-not-found error.
    public func spans(_ text: String, language: String?) throws -> [TextSpan] {
        let tokens = try highlighter.tokenize(text, language: language.map { LanguageID(rawValue: $0) })
        let source = text as NSString
        return tokens.map { token in
            TextSpan(source.substring(with: token.range), role: role(for: token.kind))
        }
    }

    private func role(for kind: TokenKind) -> TextRole {
        switch kind {
        case .keyword: .syntaxKeyword
        case .type: .syntaxType
        case .function: .syntaxFunction
        case .string: .success
        case .number: .warning
        case .comment: .muted
        case .property: .syntaxProperty
        default: .normal
        }
    }
}
