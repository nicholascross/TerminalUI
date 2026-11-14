import TerminalUI
import Testing

struct ConversationLayoutTests {
    @Test func focusedEmptyEditorPreservesThePlaceholderUnderItsCursor() throws {
        let engine = UIEngine()
        let view = Element.textEditor(id: "composer", value: "", placeholder: "Describe work")
        #expect(engine.focus("composer", in: view))
        let grid = engine.renderGrid(view, width: 20, height: 1)
        #expect(grid.lines[0].contains("Describe work"))
        #expect(try #require(grid[0, 0]).style.reversed)
        #expect(engine.handle(.paste("Keep\nthis"), in: view) == .textChanged("composer", "Keep\nthis"))
    }

    @Test func `following end preserves inspection across updates focus and resize`() {
        let engine = UIEngine()
        func view(_ count: Int) -> Element {
            .column([
                .scrollView(id: "history", content: .column((0 ..< count).map { .text("Line \($0)") }), followsEnd: true).height(.fill()),
                .textEditor(id: "composer", value: "draft").height(.fixed(1)),
            ])
        }
        #expect(engine.focus("composer", in: view(10)))
        #expect(engine.render(view(10), width: 20, height: 5)[3].contains("Line 9"))
        #expect(engine.render(view(11), width: 20, height: 5)[3].contains("Line 10"))
        #expect(engine.focus("history", in: view(11)))
        _ = engine.handle(.pageUp, in: view(11))
        let inspected = engine.render(view(11), width: 20, height: 5)
        #expect(inspected[0].contains("Line 3"))
        #expect(engine.focus("composer", in: view(11)))
        #expect(engine.render(view(12), width: 20, height: 5) == inspected)
        #expect(engine.render(view(12), width: 12, height: 6)[0].contains("Line 3"))
        #expect(engine.focus("history", in: view(12)))
        _ = engine.handle(.end, in: view(12))
        #expect(engine.render(view(12), width: 12, height: 6)[4].contains("Line 11"))
        #expect(engine.render(view(13), width: 30, height: 4)[2].contains("Line 12"))
        #expect(engine.focus("composer", in: view(13)))
        #expect(engine.handle(.shiftEnter, in: view(13)) == .textChanged("composer", "draft\n"))
    }

    @Test func `wrapped list keeps selection visible and pages by visible tasks`() throws {
        let engine = UIEngine()
        let rows = (0 ..< 8).map { ListRow(id: "\($0)", title: "Task \($0) with a long description that wraps onto several lines") }
        func view(_ selection: String) -> Element {
            .list(id: "tasks", rows: rows, selection: selection, lineLimit: 2, rowSpacing: 1).onSubmit("open")
        }
        #expect(engine.focus("tasks", in: view("0")))
        let frame = engine.renderGrid(view("0"), width: 25, height: 8)
        #expect(frame.lines[0].hasPrefix("> Task 0"))
        #expect(frame.lines[1].contains("description") && frame.lines[1].contains("…"))
        #expect(frame.lines[2].allSatisfy { $0.isWhitespace })
        #expect(try #require(frame[24, 0]).style.reversed)
        #expect(engine.handle(.pageDown, in: view("0")) == .selectionChanged("tasks", "3"))
        #expect(engine.render(view("3"), width: 25, height: 8).joined().contains("> Task 3"))
        #expect(engine.handle(.end, in: view("3")) == .selectionChanged("tasks", "7"))
        #expect(engine.render(view("7"), width: 12, height: 1)[0].hasPrefix("> Task 7"))
        #expect(engine.handle(.enter, in: view("7")) == .activated("open"))
        #expect(engine.handle(.home, in: view("7")) == .selectionChanged("tasks", "0"))
    }
}

extension ConversationLayoutTests {
    @Test func mixedListRowsUseTheirActualWrappedHeight() throws {
        let engine = UIEngine()
        let rows = [ListRow(id: "a", title: "Short A"), ListRow(id: "b", title: "This description needs two lines"),
                    ListRow(id: "c", title: "Short C")]
        let view = Element.column([
            .list(id: "tasks", rows: rows, selection: "b", lineLimit: 2),
            .text("Details follow"),
        ])
        #expect(engine.focus("tasks", in: view))
        let grid = engine.renderGrid(view, width: 24, height: 20)
        #expect(grid.lines[0].hasPrefix("  Short A"))
        #expect(grid.lines[1].hasPrefix("> This description"))
        #expect(grid.lines[2].hasPrefix("  two lines"))
        #expect(grid.lines[3].hasPrefix("  Short C"))
        #expect(grid.lines[4].hasPrefix("Details follow"))
        for row in 0...4 { #expect(grid[23, row]?.style.reversed == (row == 1 || row == 2)) }
    }

    @Test func cappedContentReservesAdjacentControlsAndLeavesUnusedSpaceBelow() {
        let engine = UIEngine()
        func view(_ count: Int) -> Element {
            .column([
                .column([
                    .list(id: "tasks", rows: (0..<count).map { ListRow(id: "\($0)", title: "Task \($0)") }, selection: "0")
                        .height(.fit(maximum: 20)),
                    .text("Selected task"),
                ]).height(.fill()),
                .textEditor(id: "composer", value: "draft").height(.fixed(1)),
            ])
        }
        let short = engine.render(view(2), width: 20, height: 10)
        #expect(short[2].hasPrefix("Selected task"))
        #expect(short[3...8].allSatisfy { $0.allSatisfy(\.isWhitespace) })
        let full = engine.render(view(20), width: 20, height: 10)
        #expect(full[8].hasPrefix("Selected task") && full[9].hasPrefix("draft"))
    }
}
