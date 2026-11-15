import Foundation
import TerminalUIEngine
import Testing

struct ComponentBehaviorTests {
    @Test func listSubmitRequiresNonemptyEnabledListAndExplicitAction() {
        let engine = UIEngine()
        let list = Element.list(id: "tasks", rows: [ListRow(id: "one", title: "Task")], selection: "one")
        #expect(engine.handle(.enter, in: list) == .unhandledKey(.enter))
        #expect(engine.handle(.enter, in: list.onSubmit("open")) == .activated("open"))
        #expect(engine.handle(.enter, in: list.onSubmit("open").enabled(false)) == .unhandledKey(.enter))
        let empty = Element.list(id: "empty", rows: [], selection: nil).onSubmit("open")
        #expect(engine.handle(.enter, in: empty) == .unhandledKey(.enter))
    }

    @Test func tabsUseControlledSelectionAndKeyboardNavigation() {
        let engine = UIEngine()
        let tabs = [Tab(id: "a", title: "Alpha"), Tab(id: "b", title: "Beta"), Tab(id: "c", title: "Gamma")]
        let view = Element.tabs(id: "sections", tabs: tabs, selection: "a")
        #expect(engine.render(view, width: 20, height: 1)[0].contains(">*Alpha"))
        #expect(engine.handle(.right, in: view) == .selectionChanged("sections", "b"))
        #expect(engine.handle(.left, in: view) == nil)
        let updated = Element.tabs(id: "sections", tabs: tabs, selection: "c")
        #expect(engine.render(updated, width: 8, height: 1)[0].contains("Gamma"))
        #expect(engine.handle(.home, in: updated) == .selectionChanged("sections", "a"))
        #expect(engine.handle(.end, in: updated) == nil)
        #expect(engine.handle(.enter, in: updated) == .unhandledKey(.enter))
        #expect(engine.handle(.right, in: view.enabled(false)) == .unhandledKey(.right))
        #expect(engine.handle(.right, in: .tabs(id: "empty", tabs: [], selection: nil)) == .unhandledKey(.right))
    }

    @Test func progressClampsAndHandlesNonFiniteValues() {
        let engine = UIEngine()
        for (value, expected) in [(-1.0, "0%"), (0.426, "43%"), (2, "100%"), (.nan, "0%"), (.infinity, "0%")] {
            #expect(engine.render(.progress(value), width: 4, height: 1)[0].trimmingCharacters(in: .whitespaces) == expected)
        }
    }
    @Test func scrollEndAndResizeClampTheViewport() {
        let engine = UIEngine()
        let view = Element.scrollView(id: "s", content: .paragraph("one\ntwo\nthree\nfour"))
        _ = engine.render(view, width: 10, height: 2)
        _ = engine.handle(.end, in: view)
        #expect(engine.render(view, width: 10, height: 2).map { $0.trimmingCharacters(in: .whitespaces) } == ["three", "four"])
        #expect(engine.render(view, width: 10, height: 3).first?.hasPrefix("two") == true)
        _ = engine.handle(.down, in: view)
        #expect(engine.render(view, width: 10, height: 3).first?.hasPrefix("two") == true)
    }

    @Test func scrollingKeepsFocusedChildVisible() {
        let engine = UIEngine()
        let view = Element.scrollView(id: "s", content: .column([
            .button("first", id: "first"), .text("middle"), .button("last", id: "last")
        ]))
        _ = engine.render(view, width: 12, height: 2)
        _ = engine.handle(.tab, in: view)
        _ = engine.handle(.tab, in: view)
        #expect(engine.render(view, width: 12, height: 2).joined().contains("last"))
        #expect(engine.handle(.enter, in: view) == .activated("last"))
    }

    @Test func focusMovesToRemainingSuccessor() {
        let engine = UIEngine()
        let old = Element.column([.button("a", id: "a"), .button("b", id: "b"), .button("c", id: "c")])
        _ = engine.handle(.tab, in: old)
        let updated = Element.column([.button("a", id: "a"), .button("c", id: "c")])
        #expect(engine.handle(.enter, in: updated) == .activated("c"))
    }

    @Test func pasteNormalizesNewlines() {
        let engine = UIEngine()
        let editor = Element.textEditor(id: "e", value: "")
        #expect(engine.handle(.paste("a\r\nb\rc"), in: editor) == .textChanged("e", "a\nb\nc"))
        let field = Element.textField(id: "f", value: "")
        #expect(engine.handle(.paste("a\r\nb"), in: field) == .textChanged("f", "a b"))
    }

    @Test func customWidgetCanConsumeWithoutAction() {
        let engine = UIEngine()
        let view = Element.custom(ConsumingWidget())
        #expect(engine.handle(.left, in: view) == nil)
        #expect(engine.handle(.right, in: view) == .unhandledKey(.right))
    }
    @Test func layoutAllocatesFixedAndWeightedSpace() {
        let frame = UIEngine().render(.row([
            .text("A").width(.fixed(2)),
            .paragraph("BBBBBBBB").width(.fill(weight: 1)),
            .paragraph("CCCCCCCC").width(.fill(weight: 2))
        ]), width: 11, height: 1)
        #expect(frame == ["A BBCCCCCC "] || frame == ["A BBBCCCCCC"])
    }

    @Test func hiddenAndDisabledControlsAreSkipped() {
        let engine = UIEngine()
        let root = Element.column([
            .button("hidden", id: "hidden").visible(false),
            .button("disabled", id: "disabled").enabled(false),
            .button("active", id: "active")
        ])
        #expect(engine.handle(.enter, in: root) == .activated("active"))
        #expect(!engine.render(root, width: 25, height: 3).joined().contains("hidden"))
    }

    @Test func selectedListItemStaysVisibleAfterReorder() {
        let engine = UIEngine()
        let rows = (0..<10).map { ListRow(id: "\($0)", title: "row\($0)") }
        let list = Element.list(id: "items", rows: rows, selection: "8")
        let frame = engine.render(list, width: 12, height: 3)
        #expect(frame.joined().contains("row8"))
        #expect(engine.handle(.up, in: list) == .selectionChanged("items", "7"))
        let reordered = Element.list(id: "items", rows: Array(rows.reversed()), selection: "8")
        #expect(engine.render(reordered, width: 12, height: 3).joined().contains("row8"))
    }

    @Test func scrollViewRespondsToKeys() {
        let engine = UIEngine()
        let root = Element.scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour"))
        #expect(engine.render(root, width: 10, height: 2).first?.contains("one") == true)
        #expect(engine.handle(.down, in: root) == nil)
        #expect(engine.render(root, width: 10, height: 2).first?.contains("two") == true)
    }

    @Test func editorNavigationAndControlledValue() {
        let engine = UIEngine()
        let root = Element.textEditor(id: "editor", value: "abc\ndef")
        #expect(engine.handle(.up, in: root) == nil)
        #expect(engine.handle(.character("!"), in: root) == .textChanged("editor", "abc!\ndef"))
        engine.resetState(for: "editor")
        #expect(engine.handle(.backspace, in: root) == .textChanged("editor", "abc\nde"))
    }

    @Test func customWidgetParticipatesInFocusAndDrawing() {
        let engine = UIEngine()
        let root = Element.custom(TestWidget())
        #expect(engine.render(root, width: 10, height: 1)[0].hasPrefix("focused"))
        #expect(engine.handle(.enter, in: root) == .activated("custom"))
    }
}

private struct ConsumingWidget: CustomWidget {
    let id: String? = "consumer"
    let isFocusable = true
    func measure(width: Int) -> WidgetSize { .init(width: 1, height: 1) }
    func draw(in canvas: inout Canvas, focused: Bool) {}
    func respond(to key: KeyEvent, theme: Theme) -> WidgetResponse {
        key == .left ? .consumed : .unhandled
    }
}

private struct TestWidget: CustomWidget {
    let id: String? = "custom"
    let isFocusable = true
    func measure(width: Int) -> WidgetSize { .init(width: 7, height: 1) }
    func draw(in canvas: inout Canvas, focused: Bool) { canvas.write(focused ? "focused" : "idle", x: 0, y: 0) }
    func handle(_ key: KeyEvent) -> UIAction? { key == .enter ? .activated("custom") : nil }
}

extension ComponentBehaviorTests {
    @Test func selectionReplacesAndDeletesGraphemes() {
        let engine = UIEngine()
        let view = Element.textField(id: "value", value: "a🙂c")
        #expect(engine.handle(.shiftLeft, in: view) == nil)
        #expect(engine.handle(.shiftLeft, in: view) == nil)
        #expect(engine.handle(.character("!"), in: view) == .textChanged("value", "a!"))
        engine.resetState(for: "value")
        _ = engine.handle(.shiftLeft, in: view)
        #expect(engine.handle(.backspace, in: view) == .textChanged("value", "a🙂"))
    }
}

extension ComponentBehaviorTests {
    @Test func paragraphWrapsAtWordsAndNormalizesTabsAndNewlines() {
        let engine = UIEngine()
        let frame = engine.render(.paragraph("one two three\r\nfour\tfive"), width: 7, height: 4)
        #expect(frame[0].trimmingCharacters(in: .whitespaces) == "one two")
        #expect(frame[1].trimmingCharacters(in: .whitespaces) == "three")
        #expect(frame[2].trimmingCharacters(in: .whitespaces) == "four")
        #expect(frame[3].trimmingCharacters(in: .whitespaces) == "five")
    }

    @Test func editorKeepsCaretVisibleOnResize() {
        let engine = UIEngine()
        let view = Element.textEditor(id: "value", value: "abcdefghij")
        let grid = engine.renderGrid(view, width: 4, height: 1)
        #expect(grid.lines[0].contains("ij"))
        #expect((0..<grid.width).contains { grid[$0, 0]?.style.reversed == true })
        let resized = engine.renderGrid(view, width: 3, height: 1)
        #expect((0..<resized.width).contains { resized[$0, 0]?.style.reversed == true })
    }
}

extension ComponentBehaviorTests {
    @Test func editorMovesBetweenVisualRowsAfterResize() {
        let engine = UIEngine()
        let view = Element.textEditor(id: "editor", value: "abcdefghij")
        _ = engine.render(view, width: 4, height: 3)
        #expect(engine.handle(.up, in: view) == nil)
        #expect(engine.handle(.character("!"), in: view) == .textChanged("editor", "abcdef!ghij"))
        engine.resetState(for: "editor")
        _ = engine.render(view, width: 3, height: 4)
        #expect(engine.handle(.up, in: view) == nil)
        #expect(engine.handle(.character("!"), in: view) == .textChanged("editor", "abcdefg!hij"))
    }
}

extension ComponentBehaviorTests {
    @Test func extremeDimensionsAndInsetsRemainBounded() {
        let engine = UIEngine()
        let insets = Insets(top: Int.max, leading: Int.max, bottom: Int.min, trailing: Int.min)
        let view = Element.column(spacing: Int.max, [.text("x").padding(insets), .spacer()])
        let frame = engine.render(view, width: 4, height: 2)
        #expect(frame.count == 2)
        #expect(frame.allSatisfy { $0.count <= 4 })
    }
}

extension ComponentBehaviorTests {
    @Test func verticalSelectionAndPreferredColumnSurviveShortLines() {
        let engine = UIEngine()
        let view = Element.textEditor(id: "editor", value: "abcd\nx\nwxyz")
        _ = engine.render(view, width: 10, height: 3)
        _ = engine.handle(.up, in: view)
        _ = engine.handle(.up, in: view)
        #expect(engine.handle(.character("!"), in: view) == .textChanged("editor", "abcd!\nx\nwxyz"))
        engine.resetState(for: "editor")
        _ = engine.render(view, width: 10, height: 3)
        _ = engine.handle(.shiftUp, in: view)
        #expect(engine.handle(.character("!"), in: view) == .textChanged("editor", "abcd\nx!"))
    }
}

extension ComponentBehaviorTests {
    @Test func differentWidgetKindsHaveIndependentStateForSameID() {
        let engine = UIEngine()
        let field = Element.textField(id: "shared", value: "abcd")
        let editor = Element.textEditor(id: "shared", value: "abcd")
        _ = engine.handle(.left, in: field)
        #expect(engine.handle(.character("!"), in: editor) == .textChanged("shared", "abcd!"))
        #expect(engine.handle(.character("?"), in: field) == .textChanged("shared", "abc?d"))
        engine.resetState(for: "shared")
        #expect(engine.handle(.character("?"), in: field) == .textChanged("shared", "abcd?"))
        #expect(engine.handle(.character("!"), in: editor) == .textChanged("shared", "abcd!"))
    }
}

extension ComponentBehaviorTests {
    @Test func textTruncatesAndAlignsWithoutSplittingWideCharacters() {
        let engine = UIEngine()
        #expect(engine.render(.text("ab界cd"), width: 4, height: 2) == ["ab… ", "    "])
        #expect(engine.render(.text("hi").alignment(.trailing), width: 5, height: 1) == ["   hi"])
        #expect(engine.render(.text("one\ntwo"), width: 5, height: 2) == ["one  ", "     "])
    }

    @Test func stackAlignmentHonorsCrossAxisSizes() {
        let engine = UIEngine()
        let column = Element.column([.text("x"), .text("y").width(.fixed(3))]).alignment(.trailing)
        #expect(engine.render(column, width: 5, height: 2) == ["    x", "  y  "])
        let row = Element.row([.text("x").height(.fixed(1))]).alignment(.trailing)
        #expect(engine.render(row, width: 3, height: 2) == ["   ", "x  "])
    }

    @Test func programmaticFocusRespectsVisibilityAndDialogAndScrollsToControl() {
        let engine = UIEngine()
        let root = Element.scrollView(id: "scroll", content: .column([
            .button("first", id: "first"), .text("middle"), .button("last", id: "last")
        ]))
        #expect(engine.focus("last", in: root))
        #expect(engine.render(root, width: 12, height: 2).joined().contains("last"))
        #expect(engine.handle(.enter, in: root) == .activated("last"))
        let modal = root.overlay(.dialog(id: "dialog", title: "Confirm", content: .button("ok", id: "ok")))
        #expect(!engine.focus("first", in: modal))
        #expect(engine.focus("ok", in: modal))
        #expect(!engine.focus("missing", in: modal))
    }

    @Test func inactiveWidgetStateIsBoundedAndRecentStateSurvives() {
        let engine = UIEngine()
        for index in 0..<260 {
            let field = Element.textField(id: "\(index)", value: "ab")
            _ = engine.handle(.left, in: field)
            _ = engine.render(field, width: 5, height: 1)
        }
        _ = engine.render(.text("empty"), width: 5, height: 1)
        #expect(engine.handle(.character("!"), in: .textField(id: "0", value: "ab")) == .textChanged("0", "ab!"))
        #expect(engine.handle(.character("!"), in: .textField(id: "259", value: "ab")) == .textChanged("259", "a!b"))
    }
}

extension ComponentBehaviorTests {
    @Test func insertingCombiningMarksKeepsCaretAtGraphemeBoundary() {
        let engine = UIEngine()
        let original = Element.textField(id: "field", value: "ab")
        _ = engine.handle(.left, in: original)
        #expect(engine.handle(.paste("\u{301}"), in: original) == .textChanged("field", "a\u{301}b"))
        let updated = Element.textField(id: "field", value: "a\u{301}b")
        #expect(engine.handle(.character("!"), in: updated) == .textChanged("field", "a\u{301}!b"))
    }
}

extension ComponentBehaviorTests {
    @Test func styledParagraphWrapsAndRetainsRoles() {
        var theme = Theme()
        theme.warning = TextStyle(foreground: .red)
        let engine = UIEngine(theme: theme)
        let view = Element.paragraph([TextSpan("one "), TextSpan("two", role: .warning)])
        let grid = engine.renderGrid(view, width: 4, height: 2)
        #expect(grid.lines == ["one ", "two "])
        #expect(grid[0, 0]?.style == theme.normal)
        #expect(grid[0, 1]?.style == theme.warning)
        #expect(grid[2, 1]?.style == theme.warning)
    }

    @Test func keepVisibleRevealsNonFocusableContent() {
        let engine = UIEngine()
        let root = Element.scrollView(id: "scroll", content: .column([
            .text("one"), .text("two"), .text("three").id("target"), .text("four")
        ]))
        engine.keepVisible("target")
        #expect(engine.render(root, width: 6, height: 2) == ["two   ", "three "])
        #expect(engine.focusedID == "scroll")
        #expect(engine.render(root, width: 6, height: 2) == ["two   ", "three "])
    }

    @Test func contextualCustomWidgetReceivesProposalAndInput() {
        let engine = UIEngine()
        let view = Element.custom(ContextWidget())
        #expect(engine.render(view, width: 4, height: 1) == ["4   "])
        #expect(engine.handle(.enter, in: view) == .activated("context"))
    }
}

private struct ContextWidget: CustomWidget {
    let id: String? = "context"
    let isFocusable = true
    func measure(context: WidgetMeasureContext) -> WidgetSize { .init(width: context.width, height: 1) }
    func draw(in canvas: inout Canvas, context: WidgetDrawContext) {
        canvas.write("\(context.size.width)", x: 0, y: 0, style: context.theme.normal)
    }
    func respond(to key: KeyEvent, context: WidgetEventContext) -> WidgetResponse {
        key == .enter && context.focused ? .action(.activated("context")) : .unhandled
    }
}

extension ComponentBehaviorTests {
    @Test func editorCaretAtNewlineAfterFullVisualRowRemainsVisible() {
        let engine = UIEngine()
        let view = Element.textEditor(id: "editor", value: "abc\nx")
        _ = engine.render(view, width: 3, height: 2)
        _ = engine.handle(.left, in: view)
        _ = engine.handle(.left, in: view)
        let grid = engine.renderGrid(view, width: 3, height: 2)
        #expect(grid.lines[0] == "abc")
        #expect(grid[0, 1]?.style.reversed == true)
        #expect(engine.handle(.character("!"), in: view) == .textChanged("editor", "abc!\nx"))
    }

    @Test func editorRetainsViewportUntilCaretLeavesIt() {
        let engine = UIEngine()
        let view = Element.textEditor(id: "editor", value: "aa\nbb\ncc\ndd")
        #expect(engine.renderGrid(view, width: 4, height: 2).lines == ["cc  ", "dd  "])
        _ = engine.handle(.up, in: view)
        #expect(engine.renderGrid(view, width: 4, height: 2).lines == ["cc  ", "dd  "])
        _ = engine.handle(.up, in: view)
        #expect(engine.renderGrid(view, width: 4, height: 2).lines == ["bb  ", "cc  "])
    }

    @Test func fieldShowsClippedWideGlyphAtViewportEdge() {
        let engine = UIEngine()
        let view = Element.textField(id: "field", value: "界a")
        let grid = engine.renderGrid(view, width: 3, height: 1)
        #expect(grid.lines == ["�a "])
        #expect(grid[2, 0]?.style.reversed == true)
    }
}

extension ComponentBehaviorTests {
    @Test func keepVisiblePropagatesThroughNestedScrollViews() {
        let engine = UIEngine()
        let inner = Element.scrollView(id: "inner", content: .column([
            .text("a"), .text("b"), .text("target").id("target")
        ])).height(.fixed(2))
        let outer = Element.scrollView(id: "outer", content: .column([
            .text("top"), .text("middle"), inner
        ]))
        engine.keepVisible("target")
        #expect(engine.render(outer, width: 8, height: 2).contains { $0.hasPrefix("target") })
    }
}

@Test func editorSubmissionAndNewline() {
    let engine = UIEngine()
    let editor = Element.textEditor(id: "question", value: "hello").onSubmit("ask")
    #expect(engine.handle(.enter, in: editor) == .activated("ask"))
    #expect(engine.handle(.shiftEnter, in: editor) == .textChanged("question", "hello\n"))
    #expect(engine.handle(.paste("a\nb"), in: editor) == .textChanged("question", "helloa\nb"))
    let ordinary = Element.textEditor(id: "notes", value: "note")
    #expect(engine.handle(.enter, in: ordinary) == .textChanged("notes", "note\n"))
}

extension ComponentBehaviorTests {
    @Test func tableSelectionViewportAndResize() {
        let engine = UIEngine()
        let columns = [TableColumn("Name", width: .fill()), TableColumn("State", width: .fixed(5))]
        let rows = (0..<6).map { TableRow(id: "\($0)", cells: ["Item\($0)", "ok"]) }
        let table = Element.table(id: "tasks", columns: columns, rows: rows, selection: "4")
        let frame = engine.render(table, width: 16, height: 3)
        #expect(frame[0].contains("Name") && frame[0].contains("State"))
        #expect(frame[2].contains("Item4"))
        #expect(engine.handle(.pageUp, in: table) == .selectionChanged("tasks", "2"))
        #expect(engine.handle(.end, in: table) == .selectionChanged("tasks", "5"))
        #expect(engine.handle(.enter, in: table) == .unhandledKey(.enter))
        let reordered = Element.table(id: "tasks", columns: columns, rows: rows.reversed(), selection: "4")
        #expect(engine.render(reordered, width: 16, height: 2)[1].contains("Item4"))
        #expect(engine.handle(.down, in: table.enabled(false)) == .unhandledKey(.down))
    }

    @Test func tableClipsCellsAndHandlesEmptyAndMismatchedRows() {
        let engine = UIEngine()
        let columns = [TableColumn("A", width: .fixed(3)), TableColumn("B", width: .fill())]
        let table = Element.table(id: "t", columns: columns, rows: [
            TableRow(id: "a", cells: ["界abc", "yes", "extra"]),
            TableRow(id: "b", cells: [])
        ], selection: "a")
        let frame = engine.render(table, width: 10, height: 3)
        #expect(frame[1].contains("界…"))
        #expect(frame[1].contains("yes"))
        #expect(!frame.joined().contains("extra"))
        #expect(engine.render(table, width: 1, height: 1).count == 1)
        let empty = Element.table(id: "empty", columns: [], rows: [], selection: nil)
        #expect(engine.handle(.down, in: empty) == .unhandledKey(.down))
        #expect(engine.render(empty, width: 10, height: 2)[1].contains("empty"))
    }
}

extension ComponentBehaviorTests {
    @Test func borderedTableDrawsGridAndKeepsSelectionVisible() {
        let engine = UIEngine()
        let columns = [TableColumn("A", width: .fixed(3)), TableColumn("B")]
        let rows = (0..<4).map { TableRow(id: "\($0)", cells: ["r\($0)", "ok"]) }
        let view = Element.table(id: "table", columns: columns, rows: rows, selection: "2", bordered: true)
        #expect(engine.render(view, width: 12, height: 6) == [
            "┌─────┬────┐", "│  A  │B   │", "├─────┼────┤",
            "│  r1 │ok  │", "│> r2 │ok  │", "└─────┴────┘"
        ])
        #expect(engine.handle(.pageUp, in: view) == .selectionChanged("table", "0"))
        #expect(engine.render(view, width: 12, height: 5)[3].contains("r2"))
    }

    @Test func borderedTableHandlesTinyDimensions() {
        let view = Element.table(id: "table", columns: [TableColumn("Header")],
                                 rows: [TableRow(id: "a", cells: ["value"])], selection: "a", bordered: true)
        let engine = UIEngine()
        #expect(engine.render(view, width: 4, height: 2) == ["┌──┐", "└──┘"])
        let empty = Element.table(id: "empty", columns: [], rows: [], selection: nil, bordered: true)
        #expect(engine.render(empty, width: 4, height: 5)[3] == "│> │")
        for width in 0...4 {
            for height in 0...4 {
                let grid = engine.renderGrid(view, width: width, height: height)
                #expect(grid.width == width && grid.height == height)
            }
        }
    }
}
