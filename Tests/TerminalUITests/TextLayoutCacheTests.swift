import TerminalUIEngine
import TerminalUILayoutEngine
@testable import TerminalUIRendering
import TerminalUIText
import Testing

struct TextLayoutCacheTests {
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
