import TerminalUIEngine
import Testing

@Suite struct CellGridTests {
    @Test func asciiFastPathKeepsControlFilteringAndCombiningMarks() {
        for value in UInt8(0)...UInt8(127) {
            let character = Character(UnicodeScalar(value))
            #expect(CellWidth.width(of: character) == 1)
            #expect(CellWidth.isSafe(character) == (value >= 32 && value != 127))
        }
        #expect(CellWidth.width(of: "e\u{301}") == 1)
        #expect(CellWidth.isSafe("e\u{301}"))
        #expect(CellWidth.width(of: "\u{301}") == 0)
    }

    @Test func unicodeWidthAndOverwrite() {
        #expect(CellWidth.width(of: "界") == 2)
        #expect(CellWidth.width(of: "e\u{301}") == 1)
        #expect(CellWidth.width(of: "👩‍💻") == 2)
        #expect(CellWidth.width(of: "🇦🇺") == 2)
        var canvas = Canvas(width: 5, height: 1)
        canvas.write("a界b", x: 0, y: 0)
        #expect(canvas.grid[1, 0]?.width == 2)
        #expect(canvas.grid[2, 0]?.width == 0)
        canvas.write("X", x: 2, y: 0)
        #expect(canvas.grid.lines == ["a Xb "])
        canvas.write("界", x: 4, y: 0)
        #expect(canvas.grid.lines == ["a Xb�"])
    }

    @Test @MainActor func engineWrapsByDisplayCells() {
        let engine = UIEngine()
        let grid = engine.renderGrid(.paragraph("a界b"), width: 2, height: 3)
        #expect(grid.lines == ["a ", "界", "b "])
        #expect(grid[0, 1]?.width == 2)
        #expect(grid[1, 1]?.width == 0)
        #expect(engine.renderGrid(.paragraph("界"), width: 1, height: 1).lines == ["�"])
    }

    @Test @MainActor func semanticStylesReachGridAndCanBeOverridden() {
        var theme = Theme()
        theme.warning = TextStyle(foreground: .red, bold: true)
        let engine = UIEngine(theme: theme)
        let grid = engine.renderGrid(.text("warning").role(.warning), width: 8, height: 1)
        #expect(grid[0, 0]?.style == theme.warning)
    }

    @Test func colorsCanBeDisabledWithoutRemovingEmphasis() {
        var canvas = Canvas(width: 1, height: 1)
        canvas.write("x", x: 0, y: 0, style: TextStyle(foreground: .red, bold: true))
        var encoder = FrameEncoder(colorEnabled: false)
        let output = encoder.prepare(canvas.grid)
        #expect(output.contains("\u{1b}[0;1m"))
        #expect(!output.contains("31m"))
    }

    @Test func textControlsCannotEscapeEncoder() {
        var canvas = Canvas(width: 16, height: 1)
        canvas.write("\u{1b}[2J\u{202e}test", x: 0, y: 0)
        var encoder = FrameEncoder()
        let output = encoder.prepare(canvas.grid)
        #expect(!output.contains("\u{1b}[2J"))
        #expect(!output.contains("\u{202e}"))
    }

    @Test func frameCommitsAndDiscardInvalidates() {
        var canvas = Canvas(width: 3, height: 2)
        canvas.write("one", x: 0, y: 0)
        var encoder = FrameEncoder()
        let first = encoder.prepare(canvas.grid)
        #expect(first.contains("one"))
        encoder.commit()
        #expect(encoder.prepare(canvas.grid).isEmpty)
        encoder.commit()
        canvas.write("x", x: 1, y: 1)
        let changed = encoder.prepare(canvas.grid)
        #expect(!changed.contains("one"))
        #expect(changed.contains("\u{1b}[2;2H"))
        encoder.discard()
        #expect(encoder.prepare(canvas.grid).contains("one"))
    }

    @Test func diffRepaintsWideGlyphFootprintsAndSeparateRuns() {
        var canvas = Canvas(width: 8, height: 1)
        canvas.write("a界bcdef", x: 0, y: 0)
        var encoder = FrameEncoder()
        _ = encoder.prepare(canvas.grid)
        encoder.commit()
        canvas.write("X", x: 2, y: 0)
        canvas.write("Y", x: 6, y: 0)
        let output = encoder.prepare(canvas.grid)
        #expect(output.contains("\u{1b}[1;2H"))
        #expect(output.contains(" X"))
        #expect(output.contains("\u{1b}[1;7H"))
        #expect(!output.contains("bcd"))
    }

    @Test func clipAndClearPreserveWideCellIntegrity() {
        var canvas = Canvas(width: 3, height: 1)
        canvas.write("界", x: -1, y: 0)
        #expect(canvas.grid.lines == ["�  "])
        canvas.write("界", x: 0, y: 0)
        canvas.clear(x: 1, y: 0, width: 1, height: 1)
        #expect(canvas.grid.lines == ["   "])
    }
}
