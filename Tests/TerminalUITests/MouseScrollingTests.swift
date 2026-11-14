import TerminalUI
@testable import TerminalUIRendering
import Testing

struct MouseScrollingTests {
    @Test func `automatic focus fallback reveals the new control after manual scroll`() {
        let engine = UIEngine()
        func root(showField: Bool) -> Element {
            .scrollView(id: "scroll", content: .column([
                .textField(id: "field", value: "draft").visible(showField),
                .paragraph((0 ..< 8).map { "line\($0)" }.joined(separator: "\n")),
                .button("Last", id: "last"),
            ]))
        }
        #expect(engine.focus("field", in: root(showField: true)))
        _ = engine.render(root(showField: true), width: 16, height: 3)
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 2, row: 1))
        _ = engine.repaintGrid(width: 16, height: 3)
        let frame = engine.render(root(showField: false), width: 16, height: 3)
        #expect(engine.focusedID == "last")
        #expect(frame[2].contains("[Last]"))
    }

    @Test func `wheel scrolls hovered viewport without changing keyboard focus`() {
        let engine = UIEngine()
        let root = Element.column([
            .textField(id: "draft", value: "text"),
            .row([
                .scrollView(id: "left", content: .paragraph((0 ..< 10).map { "L\($0)" }.joined(separator: "\n"))).width(.fill()),
                .scrollView(id: "right", content: .paragraph((0 ..< 10).map { "R\($0)" }.joined(separator: "\n"))).width(.fill()),
            ]).height(.fixed(3)),
        ])
        _ = engine.render(root, width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.scrollDown, column: 15, row: 2)) == .repaint)
        let frame = engine.repaintGrid(width: 20, height: 4)
        #expect(frame.lines[1].hasPrefix("L0        R3"))
        #expect(frame.lines[3].hasPrefix("L2        R5"))
        #expect(engine.focusedID == "draft")
        for _ in 0 ..< 5 {
            _ = engine.handleMouseEvent(.init(.scrollDown, column: 15, row: 2))
            _ = engine.repaintGrid(width: 20, height: 4)
        }
        #expect(engine.repaintGrid(width: 20, height: 4).lines[3].hasPrefix("L2        R9"))
    }

    @Test func `manual scrolling can hide focused child until keyboard interaction reveals it`() {
        let engine = UIEngine()
        let root = Element.scrollView(id: "scroll", content: .column([
            .textField(id: "field", value: "draft"),
            .paragraph((0 ..< 10).map { "line\($0)" }.joined(separator: "\n")),
        ]))
        #expect(engine.focus("field", in: root))
        _ = engine.render(root, width: 12, height: 3)
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 2, row: 1))
        #expect(engine.repaintGrid(width: 12, height: 3).lines[0].hasPrefix("line2"))
        #expect(engine.focusedID == "field")
        _ = engine.handle(.left, in: root)
        #expect(engine.render(root, width: 12, height: 3)[0].hasPrefix("draft"))
    }

    @Test func `nested scrolling falls back at boundary and preserves hit coordinates`() {
        let engine = UIEngine()
        let root = Element.scrollView(id: "outer", content: .column([
            .paragraph("outer0\nouter1\nouter2"),
            .scrollView(id: "inner", content: .paragraph("I0\nI1\nI2\nI3\nI4\nI5")).height(.fixed(2)),
            .paragraph("tail0\ntail1\ntail2"),
        ]))
        _ = engine.render(root, width: 12, height: 4)
        for expected in ["I3", "I4"] {
            _ = engine.handleMouseEvent(.init(.scrollDown, column: 1, row: 3))
            let frame = engine.repaintGrid(width: 12, height: 4)
            #expect(frame.lines[0].hasPrefix("outer0"))
            #expect(frame.lines[3].hasPrefix(expected))
        }
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 1, row: 3))
        let frame = engine.repaintGrid(width: 12, height: 4)
        #expect(frame.lines[0].hasPrefix("I4"))
        #expect(frame.lines[1].hasPrefix("I5"))
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        #expect(engine.focusedID == "inner")
    }

    @Test func `list wheel does not change selection and wrapped row hits exclude spacing`() {
        let engine = UIEngine()
        let rows = ["a", "b", "c", "d"].map { ListRow(id: $0, title: $0 + " long title") }
        let root = Element.list(id: "list", rows: rows, selection: "a", lineLimit: 2, rowSpacing: 1)
        _ = engine.render(root, width: 8, height: 6)
        #expect(engine.handleMouseEvent(.init(.press, column: 2, row: 2)).action == nil)
        _ = engine.render(root, width: 8, height: 6)
        #expect(engine.handleMouseEvent(.init(.press, column: 2, row: 4)).action == .selectionChanged("list", "b"))
        _ = engine.render(root, width: 8, height: 6)
        #expect(engine.handleMouseEvent(.init(.scrollDown, column: 2, row: 1)) == .repaint)
        let frame = engine.repaintGrid(width: 8, height: 6)
        #expect(frame.lines[0].contains("c long"))
        #expect(engine.handleMouseEvent(.init(.press, column: 2, row: 1)).action == .selectionChanged("list", "c"))
    }

    @Test(arguments: [false, true])
    func `table wheel and clicks account for headers and borders`(bordered: Bool) {
        let engine = UIEngine()
        let rows = (0 ..< 10).map { TableRow(id: "r\($0)", cells: ["row\($0)"]) }
        let root = Element.table(id: "table", columns: [TableColumn("Name")], rows: rows, selection: "r0", bordered: bordered)
        let height = bordered ? 7 : 4
        let firstRow = bordered ? 3 : 1
        _ = engine.render(root, width: 16, height: height)
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 4, row: firstRow))
        let frame = engine.repaintGrid(width: 16, height: height)
        #expect(frame.lines[firstRow].contains("row3"))
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: firstRow + 1)).action == .selectionChanged("table", "r4"))
        _ = engine.render(root, width: 16, height: height)
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: bordered ? 1 : 0)).action == nil)
    }

    @Test func `editor wheel preserves focus and caret and click uses scrolled row`() {
        let engine = UIEngine()
        let value = "L0\nL1\nL2\nL3\nL4\nL5"
        let root = Element.column([
            .textField(id: "other", value: ""),
            .textEditor(id: "editor", value: value).height(.fixed(2)),
        ])
        _ = engine.render(root, width: 10, height: 3)
        _ = engine.handleMouseEvent(.init(.scrollUp, column: 2, row: 2))
        #expect(engine.repaintGrid(width: 10, height: 3).lines[1].hasPrefix("L1"))
        #expect(engine.focusedID == "other")
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        #expect(engine.handle(.character("!"), in: root) == .textChanged("editor", "L0\nL!1\nL2\nL3\nL4\nL5"))
    }

    @Test func `follow end pauses on wheel up and resumes at bottom`() {
        let engine = UIEngine()
        func root(_ count: Int) -> Element {
            .scrollView(id: "log", content: .paragraph((0 ..< count).map { "line\($0)" }.joined(separator: "\n")), followsEnd: true)
        }
        #expect(engine.render(root(10), width: 12, height: 3)[0].hasPrefix("line7"))
        _ = engine.handleMouseEvent(.init(.scrollUp, column: 2, row: 1))
        #expect(engine.repaintGrid(width: 12, height: 3).lines[0].hasPrefix("line4"))
        #expect(engine.render(root(12), width: 12, height: 3)[0].hasPrefix("line4"))
        for _ in 0 ..< 3 {
            _ = engine.handleMouseEvent(.init(.scrollDown, column: 2, row: 1))
            _ = engine.repaintGrid(width: 12, height: 3)
        }
        #expect(engine.render(root(14), width: 12, height: 3)[0].hasPrefix("line11"))
    }
}
