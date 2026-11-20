import TerminalUIEngine
import TerminalUILayoutEngine
@testable import TerminalUIRendering
import TerminalUIText
import Testing

struct TextLayoutCacheTests {
    @Test(arguments: [false, true])
    func `no wrap measures its intrinsic width and source row count at every proposal`(styled: Bool) {
        let cache = TextLayoutCache()
        let measurement = LayoutMeasurer(textLayouts: NodeTextLayouts(cache: cache), metrics: TextMetrics())
        let paragraph = styled ? Element.paragraph([TextSpan("abcdefghij\nxy")]) : .paragraph("abcdefghij\nxy")
        let node = LayoutNode(paragraph.wrapping(false))
        for width in [3, 6] {
            let (columns, rows) = measurement.measure(node, width: width, theme: Theme())
            #expect(columns == 10)
            #expect(rows == 2)
        }
        #expect(cache.layoutCount == 1)
        node.update(paragraph)
        let (columns, rows) = measurement.measure(node, width: 3, theme: Theme())
        #expect(columns == 3)
        #expect(rows == 5)
        #expect(cache.layoutCount == 2)
    }

    @Test(arguments: [false, true])
    func `scrolling rebuilt content reuses offscreen wrapping`(styled: Bool) {
        func view() -> Element {
            .scrollView(id: "sheet", content: .column(spacing: 1, (0 ..< 12).map { index in
                let text = "Entry \(index)\n" + String(repeating: "one two 界 three 🙂 four five six seven ", count: 8)
                return .panel(title: "Section", content: styled ? .paragraph([TextSpan(text)]) : .paragraph(text))
            }))
        }
        let engine = UIEngine()
        let top = engine.renderGrid(view(), width: 24, height: 5)
        let initialLayouts = engine.textLayoutCount
        #expect(initialLayouts == 12)
        _ = engine.handle(.end, in: view())
        let bottom = engine.renderGrid(view(), width: 24, height: 5)
        #expect(bottom != top)
        for _ in 0 ..< 3 {
            _ = engine.handle(.home, in: view())
            #expect(engine.renderGrid(view(), width: 24, height: 5) == top)
            _ = engine.handle(.end, in: view())
            #expect(engine.renderGrid(view(), width: 24, height: 5) == bottom)
        }
        #expect(engine.textLayoutCount == initialLayouts)
    }

    @Test func `cached paragraphs track resize text span boundaries and draw time styles`() {
        let engine = UIEngine()
        func view(_ spans: [TextSpan]) -> Element {
            .scrollView(id: "sheet", content: .paragraph(spans))
        }
        let spans = [TextSpan("one two 界 ", role: .info), TextSpan("three 🙂 four five six seven")]
        for width in [12, 7, 12] {
            let root = view(spans)
            #expect(engine.renderGrid(root, width: width, height: 8) == UIEngine().renderGrid(root, width: width, height: 8))
        }
        #expect(engine.textLayoutCount == 2)
        var theme = Theme()
        theme.warning = TextStyle(foreground: .red, background: .blue)
        engine.theme = theme
        let styled = view([TextSpan("one two 界 ", role: .warning), TextSpan("three 🙂 four five six seven", style: .init(bold: true))])
        #expect(engine.renderGrid(styled, width: 12, height: 8) == UIEngine(theme: theme).renderGrid(styled, width: 12, height: 8))
        #expect(engine.textLayoutCount == 2)
        let split = view([TextSpan("one two "), TextSpan("界 three 🙂 four five six seven", role: .warning)])
        #expect(engine.renderGrid(split, width: 12, height: 8) == UIEngine(theme: theme).renderGrid(split, width: 12, height: 8))
        #expect(engine.textLayoutCount == 3)
        let changed = view([TextSpan("changed\r\n\tlast 界", role: .info)])
        #expect(engine.renderGrid(changed, width: 12, height: 8) == UIEngine(theme: theme).renderGrid(changed, width: 12, height: 8))
        #expect(engine.textLayoutCount == 4)
        let plain = Element.scrollView(id: "sheet", content: .paragraph("changed\r\n\tlast 界"))
        #expect(engine.renderGrid(plain, width: 12, height: 8) == UIEngine(theme: theme).renderGrid(plain, width: 12, height: 8))
        #expect(engine.textLayoutCount == 5)
    }

    @Test func `long tab-indented styled paragraphs wrap once across viewport repaints`() {
        let spans = (0 ..< 3400).flatMap { line in
            [
                TextSpan("\t\t\t\t\t\t\t\t"),
                TextSpan("let", role: .syntaxKeyword),
                TextSpan(" value\(line) = "),
                TextSpan("\(line)", role: .warning),
                TextSpan("\n"),
            ]
        }
        let theme = Theme.dark
        let engine = UIEngine(theme: theme)
        let root = Element.scrollView(id: "code", content: .paragraph(spans))
        let top = engine.renderGrid(root, width: 80, height: 8)
        #expect(top.lines[0].hasPrefix(String(repeating: " ", count: 32) + "let value0 = 0"))
        #expect(top[32, 0]?.style.foreground == theme.syntaxKeyword.foreground)
        #expect(engine.textLayoutCount == 1)

        #expect(engine.handleEvent(.end, in: root) == .repaint)
        let bottom = engine.repaintGrid(width: 80, height: 8)
        #expect(bottom.lines[6].contains("let value3399 = 3399"))
        #expect(bottom[32, 6]?.style.foreground == theme.syntaxKeyword.foreground)

        #expect(engine.handleEvent(.home, in: root) == .repaint)
        #expect(engine.repaintGrid(width: 80, height: 8) == top)
        #expect(engine.textLayoutCount == 1)
    }

    @Test func `batched styled runs preserve graphemes around expanded tabs and wrap points`() {
        let engine = UIEngine()
        let spans = [TextSpan("\t\u{0301}界"), TextSpan("\u{0301}x")]
        let grid = engine.renderGrid(.paragraph(spans), width: 9, height: 1)
        #expect(grid.lines == ["    �界�x"])
        #expect(grid[5, 0]?.width == 2)
        #expect(grid[6, 0]?.width == 0)
        #expect(engine.render(.paragraph([TextSpan("abc d\u{00a0}e")]), width: 6, height: 2) == ["abc   ", "de    "])
    }

    @Test func `cache evicts least recently used layouts within its byte budget`() {
        let cache = TextLayoutCache(budget: 100)
        #expect(cache.layout("one", width: 8).lines == ["one"])
        #expect(cache.layout("two", width: 8).lines == ["two"])
        #expect(cache.layout("one", width: 8).lines == ["one"])
        #expect(cache.layoutCount == 2)
        #expect(cache.layout("three", width: 8).lines == ["three"])
        #expect(cache.cost <= 100)
        #expect(cache.layout("one", width: 8).lines == ["one"])
        #expect(cache.layoutCount == 3)
        #expect(cache.layout("two", width: 8).lines == ["two"])
        #expect(cache.layoutCount == 4)
        #expect(cache.cost <= 100)
    }

    @Test func `node reuse refreshes recency without pinning evicted layouts`() {
        let cache = TextLayoutCache(budget: 100)
        let layouts = NodeTextLayouts(cache: cache)
        let node = LayoutNode(.paragraph("one"))
        #expect(layouts.layout("one", width: 8, retaining: node).lines == ["one"])
        _ = cache.layout("two", width: 8)
        #expect(layouts.layout("one", width: 8, retaining: node).lines == ["one"])
        _ = cache.layout("three", width: 8)
        #expect(node.textLayout != nil)
        #expect(cache.layoutCount == 3)
        _ = cache.layout("four", width: 8)
        #expect(node.textLayout == nil)
        #expect(layouts.layout("one", width: 8, retaining: node).lines == ["one"])
        #expect(cache.layoutCount == 5)
        #expect(cache.cost <= 100)
    }

    @Test func `oversized layouts render without displacing the working set`() {
        let cache = TextLayoutCache(budget: 100)
        _ = cache.layout("one", width: 8)
        let cost = cache.cost
        let text = String(repeating: "x", count: 200)
        let layouts = NodeTextLayouts(cache: cache)
        let node = LayoutNode(.paragraph(text))
        #expect(layouts.layout(text, width: 8, retaining: node).lines == Array(repeating: "xxxxxxxx", count: 25))
        #expect(node.textLayout == nil)
        #expect(cache.cost == cost)
        #expect(cache.layout("one", width: 8).lines == ["one"])
        #expect(cache.layoutCount == 2)
        let uncached = TextLayoutCache(budget: 0)
        #expect(uncached.layout("one", width: 8).lines == ["one"])
        #expect(uncached.cost == 0)
    }
}
