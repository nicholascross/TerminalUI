import TerminalUIEngine
import Testing

struct MenuTests {
    private let items = [
        MenuItem(id: "chat", title: "Conversation", shortcut: "1"),
        MenuItem(id: "activity", title: "Activity", shortcut: "2"),
        MenuItem(id: "review", title: "Review", shortcut: "3", unavailableReason: "Open a task first.")
    ]

    @Test func searchFiltersAndSubmitsTheFirstMatchWithStaleSelection() {
        let engine = UIEngine()
        let menu = Element.menu(id: "menu", title: "Menu", items: items, query: "ACT", selection: "chat")
        let screen = engine.render(menu, width: 40, height: 12).joined()
        #expect(screen.contains("Activity") && !screen.contains("Conversation") && !screen.contains("Review"))
        #expect(engine.focusedID == "menu.search")
        #expect(engine.handle(.enter, in: menu) == .activated("activity"))
        #expect(engine.handle(.down, in: menu) == nil)
        #expect(engine.focusedID == "menu.items")
        #expect(engine.handle(.enter, in: menu) == .activated("activity"))
    }

    @Test func arrowsSelectAndEnterActivatesTheSelectedItem() {
        let engine = UIEngine()
        let menu = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: "chat")
        #expect(engine.handle(.down, in: menu) == nil)
        #expect(engine.focusedID == "menu.items")
        #expect(engine.handle(.down, in: menu) == .selectionChanged("menu.items", "activity"))
        let selected = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: "activity")
        #expect(engine.handle(.enter, in: selected) == .activated("activity"))
        #expect(engine.handle(.home, in: selected) == .selectionChanged("menu.items", "chat"))
        #expect(engine.handle(.end, in: selected) == .selectionChanged("menu.items", "review"))
    }

    @Test func shortcutsApplyOnlyToEmptyQueriesAndPasteIsSearchText() {
        let engine = UIEngine()
        let menu = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: nil)
        #expect(engine.handle(.character("2"), in: menu) == .activated("activity"))
        #expect(engine.handle(.paste("2"), in: menu) == .textChanged("menu.search", "2"))
        engine.resetState(for: "menu.search")
        let filtered = Element.menu(id: "menu", title: "Menu", items: items, query: "Act", selection: nil)
        #expect(engine.focus("menu.search", in: filtered))
        #expect(engine.handle(.character("2"), in: filtered) == .textChanged("menu.search", "Act2"))
        #expect(engine.handle(.down, in: menu) == nil)
        #expect(engine.handle(.character("1"), in: menu) == .activated("chat"))
    }

    @Test(arguments: [40, 80])
    func unavailableAndEmptyResultsCannotSubmit(width: Int) {
        let engine = UIEngine()
        let menu = Element.menu(id: "menu", title: "Menu", items: items, query: "Review", selection: nil)
        let screen = engine.render(menu, width: width, height: 12).joined()
        #expect(screen.contains("[disabled] 3 Review") && screen.contains("Open a task first."))
        #expect(engine.handle(.enter, in: menu) == .unhandledKey(.enter))
        #expect(engine.handle(.down, in: menu) == nil)
        #expect(engine.handle(.enter, in: menu) != .activated("review"))
        let empty = Element.menu(id: "menu", title: "Menu", items: items, query: "missing", selection: "chat")
        #expect(engine.render(empty, width: width, height: 12).joined().contains("No matching items."))
        #expect(engine.handle(.enter, in: empty) == .unhandledKey(.enter))
        #expect(engine.handle(.escape, in: empty) == .dismissRequested("menu"))
        let noItems = Element.menu(id: "menu", title: "Menu", items: [], query: "", selection: nil)
        #expect(engine.render(noItems, width: width, height: 12).joined().contains("No matching items."))
    }

    @Test func dismissalRestoresEditorCaretAndTrapsFocus() {
        let engine = UIEngine()
        let editor = Element.textEditor(id: "draft", value: "draft")
        #expect(engine.focus("draft", in: editor))
        #expect(engine.handle(.left, in: editor) == nil)
        let root = editor.overlay(.menu(id: "menu", title: "Menu", items: items, query: "", selection: nil))
        #expect(!engine.focus("draft", in: root))
        #expect(engine.handle(.escape, in: root) == .dismissRequested("menu"))
        _ = engine.render(editor, width: 40, height: 12)
        #expect(engine.focusedID == "draft")
        #expect(engine.handle(.character("!"), in: editor) == .textChanged("draft", "draf!t"))
    }
}
