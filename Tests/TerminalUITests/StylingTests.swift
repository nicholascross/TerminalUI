import TerminalUI
import Testing

@Suite struct StylingTests {
    @Test func capabilityDetection() {
        #expect(ColorCapability.detect(environment: ["TERM": "xterm-256color", "COLORTERM": "truecolor"]) == .trueColor)
        #expect(ColorCapability.detect(environment: ["TERM": "xterm-256color"]) == .indexed256)
        #expect(ColorCapability.detect(environment: ["TERM": "xterm"]) == .ansi16)
        #expect(ColorCapability.detect(environment: ["TERM": "xterm", "NO_COLOR": "1"]) == .none)
        #expect(ColorCapability.detect(environment: ["TERM": "dumb"]) == .none)
        #expect(ColorCapability.detect(environment: ["TERM": "xterm"], interactive: false) == .none)
    }

    @Test func encodingAndFallback() {
        var canvas = Canvas(width: 2, height: 1)
        canvas.write("x", x: 0, y: 0, style: .init(foreground: .rgb(255, 0, 0), background: .indexed(42), bold: true, dim: true, italic: true, underline: true))
        var rgb = FrameEncoder(capability: .trueColor, extendedAttributes: true)
        let output = rgb.prepare(canvas.grid)
        #expect(output.contains("0;1;2;3;4;38;2;255;0;0;48;5;42m"))
        #expect(output.contains("\u{1b}[0m "))
        var basic = FrameEncoder(capability: .ansi16)
        let fallback = basic.prepare(canvas.grid)
        #expect(fallback.contains("0;1;4;91;"))
        #expect(!fallback.contains("38;2"))
        var none = FrameEncoder(capability: .none)
        #expect(!none.prepare(canvas.grid).contains("38;"))
    }

    @Test @MainActor func inheritanceAndStatePrecedence() {
        let engine = UIEngine()
        let element = Element.column([
            .text("A").underline(), .text("B").foreground(.default),
            .button("Go", id: "go"), .button("No", id: "no").enabled(false)
        ]).foreground(.red).bold()
        let grid = engine.renderGrid(element, width: 20, height: 4)
        #expect(grid[0, 0]?.style.foreground == .red)
        #expect(grid[0, 0]?.style.bold == true)
        #expect(grid[0, 0]?.style.underline == true)
        #expect(grid[0, 1]?.style.foreground == .default)
        #expect(grid[0, 1]?.style.bold == true)
        #expect(grid[0, 2]?.style == engine.theme.focused)
        #expect(grid[0, 3]?.style == engine.theme.disabled)
        #expect(grid.lines[3].contains("(disabled)"))
    }

    @Test @MainActor func richTextWrapAndThemeSwitch() {
        let engine = UIEngine()
        let element = Element.paragraph([TextSpan("a"), TextSpan("界bc", role: .error, style: .init(underline: true))])
        let first = engine.renderGrid(element, width: 3, height: 2)
        #expect(first[1, 0]?.style == TextStyle(foreground: .red, bold: true, underline: true))
        #expect(first[0, 1]?.style == first[1, 0]?.style)
        var theme = Theme()
        theme.error.foreground = .blue
        engine.theme = theme
        let second = engine.renderGrid(element, width: 3, height: 2)
        #expect(second[0, 1]?.style.foreground == .blue)
    }

    @Test func styleOnlyDiffAndReset() {
        var canvas = Canvas(width: 2, height: 1)
        canvas.write("界", x: 0, y: 0)
        var encoder = FrameEncoder(capability: .trueColor)
        _ = encoder.prepare(canvas.grid)
        encoder.commit()
        canvas.write("界", x: 0, y: 0, style: .init(background: .rgb(1, 2, 3)))
        let changed = encoder.prepare(canvas.grid)
        #expect(changed.contains("48;2;1;2;3m界"))
        #expect(changed.hasSuffix("\u{1b}[0m\u{1b}[1;1H"))
        encoder.commit()
        canvas.clear(x: 0, y: 0, width: 2, height: 1)
        #expect(encoder.prepare(canvas.grid).contains("\u{1b}[0m  "))
    }

    @Test func fillClipsAndReplacesWideGlyphs() {
        var canvas = Canvas(width: 6, height: 2)
        canvas.write("界界界", x: 0, y: 0)
        let style = TextStyle(background: .blue)
        canvas.fill(x: -1, y: -1, width: 4, height: 3, style: style)
        #expect(canvas.grid.lines == ["    界", "      "])
        for row in 0..<2 {
            for column in 0..<3 { #expect(canvas.grid[column, row]?.style == style) }
        }
        #expect(canvas.grid[4, 0]?.width == 2)
    }

    @Test func paddedScrollAndCustomSurfacesKeepTheirBackground() {
        let theme = Theme.dark
        let engine = UIEngine(theme: theme)
        let root = Element.column([
            .scrollView(id: "scroll", content: .text("short")).height(.fill()),
            .menuBar(id: "menu", items: [MenuItem(id: "item", title: "Menu")], selection: nil),
        ]).background(.blue).padding(.init(top: 1, leading: 1, bottom: 1, trailing: 1))
        let grid = engine.renderGrid(root, width: 30, height: 8)
        for row in 0..<grid.height {
            for column in 0..<grid.width { #expect(grid[column, row]?.style.background == .blue) }
        }
    }
}
