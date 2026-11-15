import TerminalUIEngine
import Testing

struct UIEventResultTests {
    @Test(arguments: [KeyEvent.up, .down, .pageUp, .pageDown, .home, .end])
    func `only built-in scroll navigation with stable focus requests a repaint`(_ key: KeyEvent) {
        let engine = UIEngine()
        let root = Element.scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour"))
        // The first input also establishes focus, which requires a view rebuild.
        let first = engine.handleEvent(key, in: root)
        #expect(first.action == nil)
        #expect(first == .rebuild(action: nil))
        _ = engine.renderGrid(root, width: 12, height: 2)
        let second = engine.handleEvent(key, in: root)
        #expect(second.action == nil)
        #expect(second == .repaint)
        #expect(engine.handle(key, in: root) == nil)
    }

    @Test func `focus actions key bindings and editor motion require rebuilding`() {
        let engine = UIEngine()
        let root = Element.column([
            .scrollView(id: "scroll", content: .text("one"))
                .onKey(.down, activate: "next"),
            .textField(id: "field", value: "value"),
            .list(id: "list", rows: [ListRow(id: "row", title: "Row")], selection: "row"),
        ])
        _ = engine.renderGrid(root, width: 20, height: 5)
        let bound = engine.handleEvent(.down, in: root)
        #expect(bound.action == .activated("next"))
        #expect(bound == .rebuild(action: .activated("next")))
        let unhandled = engine.handleEvent(.escape, in: root)
        #expect(unhandled.action == .unhandledKey(.escape))
        #expect(unhandled == .rebuild(action: .unhandledKey(.escape)))
        let focus = engine.handleEvent(.tab, in: root)
        #expect(focus.action == nil)
        #expect(focus == .rebuild(action: nil))
        #expect(engine.focusedID == "field")
        let motion = engine.handleEvent(.left, in: root)
        #expect(motion.action == nil)
        #expect(motion == .rebuild(action: nil))
        _ = engine.handleEvent(.tab, in: root)
        let selection = engine.handleEvent(.down, in: root)
        #expect(selection.action == .selectionChanged("list", "row"))
        #expect(selection == .rebuild(action: .selectionChanged("list", "row")))
    }
}
