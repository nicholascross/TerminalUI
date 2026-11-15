import TerminalUIEngine
import TerminalUIChroma
import Testing

@Suite struct SyntaxHighlighterTests {
    @Test func swiftTokensPreserveTextAndUseSemanticRoles() throws {
        let source = "let name = \"界🙂\" // comment\nprint(name)"
        let spans = try SyntaxHighlighter().spans(source, language: "swift")
        #expect(spans.map(\.text).joined() == source)
        #expect(spans.contains { $0.text == "let" && $0.role == .syntaxKeyword })
        #expect(spans.contains { $0.text.contains("界🙂") && $0.role == .success })
        #expect(spans.contains { $0.text.contains("comment") && $0.role == .muted })
    }

    @Test func plainTextAndUnknownLanguage() throws {
        let highlighter = SyntaxHighlighter()
        let source = "plain 🙂\ntext"
        let spans = try highlighter.spans(source, language: nil)
        #expect(spans.map(\.text).joined() == source)
        #expect(spans.allSatisfy { $0.role == .normal })
        #expect(throws: (any Error).self) { try highlighter.spans(source, language: "no-such-language") }
        #expect(try highlighter.spans("", language: "swift").map(\.text).joined().isEmpty)
    }

    @Test func markdownHighlightsFencedCodeAndPreservesSource() throws {
        let source = "# Example\n\n```swift\nlet value = 42\n```\n"
        let spans = try SyntaxHighlighter().spans(source, language: "markdown")
        #expect(spans.map(\.text).joined() == source)
        #expect(spans.contains { $0.text == "let" && $0.role == .syntaxKeyword })
    }

    @Test @MainActor func highlightedSpansFollowTheme() throws {
        let spans = try SyntaxHighlighter().spans("let x = 1", language: "swift")
        let engine = UIEngine()
        var theme = Theme()
        theme.syntaxKeyword.foreground = .magenta
        engine.theme = theme
        let grid = engine.renderGrid(.paragraph(spans), width: 20, height: 1)
        #expect(grid[0, 0]?.style.foreground == .magenta)
        #expect(grid.lines[0].hasPrefix("let x = 1"))
    }

    @Test @MainActor func keywordTypeAndFunctionAreDistinctInBuiltInThemes() throws {
        let source = "let value: String = convert()"
        let spans = try SyntaxHighlighter().spans(source, language: "swift")
        #expect(spans.map(\.text).joined() == source)
        #expect(spans.contains { $0.text == "let" && $0.role == .syntaxKeyword })
        #expect(spans.contains { $0.text == "String" && $0.role == .syntaxType })
        #expect(spans.contains { $0.text == "convert" && $0.role == .syntaxFunction })
        for theme in [Theme.terminalNative, .dark, .light] {
            let engine = UIEngine(theme: theme)
            let grid = engine.renderGrid(.paragraph(spans), width: 40, height: 1)
            let keyword = grid[0, 0]?.style.foreground
            let type = grid[11, 0]?.style.foreground
            let function = grid[20, 0]?.style.foreground
            #expect(keyword != type && type != function && keyword != function)
        }
    }

    @Test @MainActor func jsonKeysDifferFromValuesInBuiltInThemes() throws {
        let source = "{\"name\": \"Ada\", \"active\": true}"
        let spans = try SyntaxHighlighter().spans(source, language: "json")
        #expect(spans.map(\.text).joined() == source)
        #expect(spans.contains { $0.text == "\"name\"" && $0.role == .syntaxProperty })
        #expect(spans.contains { $0.text == "\"Ada\"" && $0.role == .success })
        for theme in [Theme.terminalNative, .dark, .light] {
            let engine = UIEngine(theme: theme)
            let grid = engine.renderGrid(.paragraph(spans), width: 40, height: 1)
            #expect(grid[1, 0]?.style.foreground == theme.syntaxProperty.foreground)
            #expect(grid[1, 0]?.style.foreground != grid[9, 0]?.style.foreground)
            #expect(grid[1, 0]?.style.foreground != grid[26, 0]?.style.foreground)
        }
    }
}
