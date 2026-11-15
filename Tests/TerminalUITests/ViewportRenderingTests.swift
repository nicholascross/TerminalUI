import TerminalUIEngine
import Testing

struct ViewportRenderingTests {
    @Test func `clipped canvas uses content coordinates and preserves wide glyphs`() {
        var canvas = Canvas(width: 6, height: 20, viewport: 10 ..< 12)
        let style = TextStyle(foreground: .red, background: .blue)
        canvas.write("hidden", x: 0, y: 9)
        canvas.write("界ab", x: 0, y: 10)
        canvas.fill(x: 1, y: 10, width: 2, height: 1, style: style)
        canvas.write("🙂", x: 0, y: 11)
        #expect(canvas.grid.lines == ["   b  ", "🙂    "])
        #expect(canvas.grid[0, 0]?.style == TextStyle())
        #expect(canvas.grid[1, 0]?.style == style && canvas.grid[2, 0]?.style == style)
        #expect(canvas.grid[0, 1]?.width == 2 && canvas.grid[1, 1]?.width == 0)
        canvas.clear(x: 1, y: 11, width: 1, height: 1)
        #expect(canvas.grid.lines == ["   b  ", "      "])
        #expect(canvas.cell(atX: 3, y: 10)?.grapheme == "b")
    }

    @Test func `fill erases wide glyphs crossing either boundary`() {
        var canvas = Canvas(width: 8, height: 1)
        canvas.write("界ab界cd", x: 0, y: 0)
        let style = TextStyle(background: .blue)
        canvas.fill(x: 1, y: 0, width: 4, height: 1, style: style)
        #expect(canvas.grid.lines == ["      cd"])
        for column in 0 ..< 8 {
            #expect(canvas.grid[column, 0]?.width == 1)
            #expect(canvas.grid[column, 0]?.style == ((1 ... 4).contains(column) ? style : TextStyle()))
        }
    }

    @Test func `scroll reveals offscreen focus and passive targets`() {
        let engine = UIEngine()
        let view = Element.scrollView(id: "history", content: .column([
            .panel(title: "Start", content: .paragraph("one\ntwo\n界 three")),
            .paragraph("four\nfive\nsix\nseven"),
            .text("passive target").id("target"),
            .button("last", id: "last"),
        ]))
        #expect(engine.render(view, width: 20, height: 3).joined().contains("Start"))
        #expect(engine.focus("last", in: view))
        let focused = engine.render(view, width: 20, height: 3)
        #expect(focused[2].hasPrefix(">[last]"))
        #expect(engine.handle(.enter, in: view) == .activated("last"))
        #expect(engine.focus("history", in: view))
        _ = engine.handle(.home, in: view)
        #expect(engine.render(view, width: 20, height: 3).joined().contains("Start"))
        engine.keepVisible("target")
        #expect(engine.render(view, width: 20, height: 3)[2].hasPrefix("passive target"))
        #expect(engine.render(view, width: 12, height: 4).joined().contains("passive"))
    }

    @Test func `nested scroll reveals focused descendants`() {
        let engine = UIEngine()
        let view = Element.scrollView(id: "outer", content: .column([
            .paragraph("a\nb\nc\nd\ne"),
            .scrollView(id: "inner", content: .column([
                .paragraph("one\ntwo\nthree\nfour"),
                .button("target", id: "target"),
            ])).height(.fixed(3)),
            .text("after"),
        ]))
        _ = engine.render(view, width: 20, height: 4)
        #expect(engine.focus("target", in: view))
        #expect(engine.render(view, width: 20, height: 4).joined().contains(">[target]"))
        #expect(engine.render(view, width: 12, height: 2).joined().contains("target"))
        #expect(engine.handle(.enter, in: view) == .activated("target"))
    }

    @Test func `cached wrapping tracks text width and theme changes`() {
        let engine = UIEngine()
        for (text, width) in [("one two 界 three", 8), ("changed\n🙂 five", 8), ("changed\n🙂 five", 4), ("one two 界 three", 12)] {
            let view = Element.scrollView(id: "history", content: .paragraph(text).role(.warning))
            #expect(engine.renderGrid(view, width: width, height: 4) == UIEngine().renderGrid(view, width: width, height: 4))
        }
        var theme = Theme()
        theme.warning = TextStyle(foreground: .blue, background: .red)
        engine.theme = theme
        let view = Element.scrollView(id: "history", content: .paragraph("one two 界 three").role(.warning))
        #expect(engine.renderGrid(view, width: 12, height: 4) == UIEngine(theme: theme).renderGrid(view, width: 12, height: 4))
    }
}
