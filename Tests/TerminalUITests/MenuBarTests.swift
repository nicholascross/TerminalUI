import TerminalUI
import Testing

struct MenuBarTests {
    private let items = [
        MenuItem(id: "chat", title: "Chat", shortcut: "1"),
        MenuItem(id: "review", title: "Review", shortcut: "2", unavailableReason: "Open a task first."),
        MenuItem(id: "quit", title: "Quit", shortcut: "q")
    ]

    @Test func drawsAllItemsHorizontallyWithIndependentFocusAndCurrentDestination() throws {
        let engine = UIEngine()
        let bar = Element.menuBar(id: "bar", items: items, selection: "chat", focusedItem: "quit")
        let grid = engine.renderGrid(bar, width: 40, height: 1)
        #expect(grid.lines[0].contains("*1 Chat") && grid.lines[0].contains("2 Review") && grid.lines[0].contains(">Q Quit"))
        let disabledIndex = try #require(grid.lines[0].firstIndex(of: "2"))
        let column = grid.lines[0].distance(from: grid.lines[0].startIndex, to: disabledIndex)
        #expect(grid[column, 0]?.style == engine.theme.disabled)
        #expect(engine.handle(.enter, in: bar) == .activated("quit"))
    }

    @Test func arrowsSelectBeforeEnterActivatesAndUnavailableItemsCannotSubmit() {
        let engine = UIEngine()
        let bar = Element.menuBar(id: "bar", items: items, selection: "chat")
        #expect(engine.handle(.right, in: bar) == .selectionChanged("bar", "review"))
        let unavailable = Element.menuBar(id: "bar", items: items, selection: "chat", focusedItem: "review")
        #expect(engine.handle(.enter, in: unavailable) == nil)
        #expect(engine.handle(.left, in: unavailable) == .selectionChanged("bar", "chat"))
        #expect(engine.handle(.home, in: unavailable) == .selectionChanged("bar", "chat"))
        #expect(engine.handle(.end, in: unavailable) == .selectionChanged("bar", "quit"))
        #expect(engine.handle(.character("2"), in: bar) == .activated("review"))
    }

    @Test func shortcutsActivateOnlyWhenFocusedAndPasteNeverActivates() {
        let engine = UIEngine()
        let bar = Element.menuBar(id: "bar", items: items, selection: "chat")
        let root = Element.column([bar, .textField(id: "draft", value: "")])
        #expect(engine.focus("draft", in: root))
        #expect(engine.handle(.character("1"), in: root) == .textChanged("draft", "1"))
        #expect(engine.focus("bar", in: root))
        #expect(engine.handle(.character("1"), in: root) == .activated("chat"))
        #expect(engine.handle(.character("Q"), in: root) == .activated("quit"))
        #expect(engine.handle(.paste("1"), in: root) == .unhandledKey(.paste("1")))
        #expect(engine.handle(.altCharacter("1"), in: root) == .unhandledKey(.altCharacter("1")))
        #expect(engine.handle(.tab, in: root) == nil)
        #expect(engine.focusedID == "draft")
    }

    @Test func narrowBarKeepsFocusedItemVisibleAndEmptyOrDisabledBarsCannotActivate() {
        let engine = UIEngine()
        let narrow = Element.menuBar(id: "bar", items: items, selection: "chat", focusedItem: "quit", compact: true)
        #expect(engine.render(narrow, width: 9, height: 1)[0].contains(">QQuit"))
        #expect(engine.handle(.enter, in: narrow) == .activated("quit"))
        let empty = Element.menuBar(id: "empty", items: [], selection: nil)
        #expect(!engine.focus("empty", in: empty))
        #expect(engine.handle(.enter, in: empty) == .unhandledKey(.enter))
        let disabled = narrow.enabled(false)
        #expect(!engine.focus("bar", in: disabled))
        #expect(engine.handle(.enter, in: disabled) == .unhandledKey(.enter))
    }
}
