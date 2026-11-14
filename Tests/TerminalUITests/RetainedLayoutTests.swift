import TerminalUI
import TerminalUILayoutEngine
import Testing

struct RetainedLayoutTests {
    @Test func `appending and removing content preserves surviving measurements`() {
        let first = Element.paragraph("first entry")
        let node = LayoutNode(.column([first]))
        let size = WidgetSize(width: 11, height: 1)
        node.children[0].remember(size, at: 20)
        #expect(node.update(.column([first, .paragraph("appended entry")])))
        #expect(node.children[0].measurement(at: 20) == size)
        #expect(node.update(.column([first])))
        #expect(node.children.count == 1)
        #expect(node.children[0].measurement(at: 20) == size)
    }

    @Test func `intrinsic sizes survive rebuilds and styling but invalidate with descendant content`() {
        func content(_ text: String, role: TextRole = .normal) -> Element {
            .panel(title: "Section", content: .paragraph([TextSpan(text, role: role)]))
        }
        let node = LayoutNode(content("one two"))
        let wide = WidgetSize(width: 9, height: 3)
        let narrow = WidgetSize(width: 5, height: 4)
        node.remember(wide, at: 20)
        node.remember(narrow, at: 5)
        #expect(!node.update(content("one two", role: .warning).background(.blue)))
        #expect(node.measurement(at: 20) == wide)
        #expect(node.measurement(at: 5) == narrow)
        #expect(node.measurement(at: 10) == nil)
        #expect(node.update(content("one two three")))
        #expect(node.measurement(at: 20) == nil)
        #expect(node.measurement(at: 5) == nil)
    }

    @Test func `rebuilt scroll content updates geometry and matches a fresh layout`() {
        let engine = UIEngine()
        let text = "one two 界 three four five six seven eight nine ten"
        let changes: [Element] = [
            .paragraph(text),
            .paragraph(text + "\nchanged\nmore"),
            .paragraph(text).padding(.all(2)),
            .paragraph(text).height(.fixed(2)),
            .paragraph(text).height(.fit(maximum: 3)),
            .column(spacing: 2, [.paragraph(text), .text("last")]),
            .row(spacing: 1, [.paragraph(text).width(.fixed(7)), .paragraph(text).width(.fill())]),
            .panel(title: "Panel", content: .paragraph(text)),
            .column([.paragraph(text).visible(false), .text("last")]),
            .button("button", id: "button").enabled(false),
            .list(id: "list", rows: [ListRow(id: "a", title: text), ListRow(id: "b", title: text)],
                  selection: nil, lineLimit: 3, rowSpacing: 1),
            .paragraph(text),
        ]
        for content in changes {
            for width in [24, 12, 24] {
                let view = Element.scrollView(id: "sheet", content: .column([content, .text("tail")]))
                let fresh = UIEngine()
                engine.resetState(for: "sheet")
                #expect(engine.focus("sheet", in: view))
                #expect(fresh.focus("sheet", in: view))
                #expect(engine.renderGrid(view, width: width, height: 4) == fresh.renderGrid(view, width: width, height: 4))
                _ = engine.handle(.end, in: view)
                _ = fresh.handle(.end, in: view)
                #expect(engine.renderGrid(view, width: width, height: 4) == fresh.renderGrid(view, width: width, height: 4))
            }
        }
    }

    @Test func `nested content measures custom widgets once per width and refreshes live state`() {
        let probe = MeasurementProbe()
        let widget = Element.custom(MeasuredWidget(probe: probe))
        func view() -> Element {
            .scrollView(id: "sheet", content: .column([
                .panel(title: "Live", content: .column([widget])),
                .text("tail"),
            ]))
        }
        let engine = UIEngine()
        let first = engine.render(view(), width: 20, height: 8)
        #expect(probe.widths == [18])
        #expect(first[3].hasPrefix("tail"))
        probe.height = 3
        probe.widths = []
        let second = engine.render(view(), width: 20, height: 8)
        #expect(probe.widths == [18])
        #expect(second[5].hasPrefix("tail"))
    }

    @Test func `styled scroll slices retain styles after wrapping resize and span changes`() {
        let engine = UIEngine()
        var theme = Theme()
        theme.info = TextStyle(foreground: .green)
        engine.theme = theme
        let variants = [
            [TextSpan("one two 界\tthree\nfour ", role: .info), TextSpan("five 🙂 six seven", style: .init(underline: true))],
            [TextSpan("one two 界\tthree\nfour ", role: .error), TextSpan("five 🙂 six seven", style: .init(bold: true))],
            [TextSpan("one two "), TextSpan("界\tthree\nfour five 🙂 six seven", role: .warning)],
            [TextSpan("changed\r\n"), TextSpan("\tlast 界", role: .accent)],
        ]
        for spans in variants {
            for width in [12, 7, 12] {
                let view = Element.scrollView(id: "sheet", content: .paragraph(spans))
                let fresh = UIEngine(theme: theme)
                engine.resetState(for: "sheet")
                #expect(engine.renderGrid(view, width: width, height: 2) == fresh.renderGrid(view, width: width, height: 2))
                _ = engine.handle(.end, in: view)
                _ = fresh.handle(.end, in: view)
                #expect(engine.renderGrid(view, width: width, height: 2) == fresh.renderGrid(view, width: width, height: 2))
            }
        }
    }
}

private final class MeasurementProbe {
    var height = 1
    var widths: [Int] = []
}

private struct MeasuredWidget: CustomWidget {
    let id: String? = nil
    let probe: MeasurementProbe

    func measure(width: Int) -> WidgetSize {
        probe.widths.append(width)
        return WidgetSize(width: width, height: probe.height)
    }
}
