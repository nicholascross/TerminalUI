import TerminalUI
import Testing

struct MouseMenuTests {
    private let items = [
        MenuItem(id: "one", title: "One"),
        MenuItem(id: "two", title: "Two"),
        MenuItem(id: "locked", title: "Locked", unavailableReason: "Unavailable"),
    ]

    @Test func `clicking nonselected menu result activates the clicked row after rebuild`() {
        let engine = UIEngine()
        let root = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: "one")
        _ = engine.render(root, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: 3)).action == .selectionChanged("menu.items", "two"))
        #expect(engine.focusedID == "menu.items")
        let selected = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: "two")
        _ = engine.render(selected, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.release, column: 4, row: 3)).action == .activated("two"))
        _ = engine.render(selected, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: 4)).action == .selectionChanged("menu.items", "locked"))
        let locked = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: "locked")
        _ = engine.render(locked, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.release, column: 4, row: 4)).action == nil)
    }

    @Test func `filtered and empty menus and mismatched releases do not activate another row`() {
        let engine = UIEngine()
        let filtered = Element.menu(id: "menu", title: "Menu", items: items, query: "Two", selection: "one")
        _ = engine.render(filtered, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: 2)).action == .selectionChanged("menu.items", "two"))
        _ = engine.render(filtered, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.release, column: 4, row: 2)).action == .activated("two"))
        let empty = Element.menu(id: "menu", title: "Menu", items: items, query: "none", selection: "one")
        _ = engine.render(empty, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: 2)).action == nil)
        _ = engine.render(empty, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.release, column: 4, row: 2)).action == nil)
        let root = Element.menu(id: "menu", title: "Menu", items: items, query: "", selection: "one")
        _ = engine.render(root, width: 30, height: 12)
        _ = engine.handleMouseEvent(.init(.press, column: 4, row: 2))
        _ = engine.render(root, width: 30, height: 12)
        #expect(engine.handleMouseEvent(.init(.release, column: 4, row: 3)).action == nil)
    }

    @Test func `menu bar uses clicked item including focus markers and unavailable items`() {
        let engine = UIEngine()
        func root(_ focused: String?) -> Element {
            .column([
                .textField(id: "other", value: ""),
                .menuBar(id: "bar", items: items, selection: "one", focusedItem: focused),
            ])
        }
        _ = engine.render(root(nil), width: 30, height: 3)
        #expect(engine.handleMouseEvent(.init(.press, column: 6, row: 1)).action == .selectionChanged("bar", "two"))
        _ = engine.render(root("two"), width: 30, height: 3)
        #expect(engine.handleMouseEvent(.init(.release, column: 6, row: 1)).action == .activated("two"))
        _ = engine.render(root("two"), width: 30, height: 3)
        #expect(engine.handleMouseEvent(.init(.press, column: 12, row: 1)).action == .selectionChanged("bar", "locked"))
        _ = engine.render(root("locked"), width: 30, height: 3)
        #expect(engine.handleMouseEvent(.init(.release, column: 12, row: 1)).action == nil)
    }

    @Test func `narrow menu bar and tabs hit only visible items`() {
        let engine = UIEngine()
        let items = [MenuItem(id: "one", title: "Alpha"), MenuItem(id: "two", title: "Beta")]
        let bar = Element.menuBar(id: "bar", items: items, selection: "two")
        #expect(engine.render(bar, width: 8, height: 1)[0].contains("Beta"))
        #expect(engine.handleMouseEvent(.init(.press, column: 3, row: 0)).action == .selectionChanged("bar", "two"))
        _ = engine.render(bar, width: 8, height: 1)
        #expect(engine.handleMouseEvent(.init(.release, column: 3, row: 0)).action == .activated("two"))
        let tabs = Element.tabs(id: "tabs", tabs: [Tab(id: "one", title: "One"), Tab(id: "two", title: "Two")], selection: "one")
        _ = engine.render(tabs, width: 16, height: 1)
        #expect(engine.handleMouseEvent(.init(.press, column: 8, row: 0)).action == .selectionChanged("tabs", "two"))
    }

    @Test func `ordinary list click selects without submitting but explicit row activation works with enter`() {
        let engine = UIEngine()
        let list = Element.list(id: "list", rows: [ListRow(id: "one", title: "One")], selection: "one").onSubmit("submit")
        _ = engine.render(list, width: 20, height: 2)
        #expect(engine.handleMouseEvent(.init(.press, column: 3, row: 0)).action == .selectionChanged("list", "one"))
        _ = engine.render(list, width: 20, height: 2)
        #expect(engine.handleMouseEvent(.init(.release, column: 3, row: 0)).action == nil)
        #expect(engine.handle(.enter, in: list) == .activated("submit"))
        let rowAction = Element.list(id: "list", rows: [ListRow(id: "one", title: "One", activationID: "open")], selection: "one")
        #expect(engine.handle(.enter, in: rowAction) == .activated("open"))
    }
}
