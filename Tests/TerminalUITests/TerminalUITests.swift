import TerminalUI
import Testing

@MainActor
struct TerminalUITests {
    @Test func rendersPanelAndClipsToBounds() {
        let engine = UIEngine()
        let view = Element.panel(title: "Notes", content: .text("hello"))
        let frame = engine.render(view, width: 12, height: 4)
        #expect(frame.count == 4)
        #expect(frame.allSatisfy { $0.count <= 12 })
        #expect(frame.joined().contains("Notes"))
        #expect(frame.joined().contains("hello"))
        #expect(engine.render(view, width: 0, height: 0).isEmpty)
    }

    @Test func solidBordersAndDividerFitTinyBounds() {
        let engine = UIEngine()
        let panel = Element.panel(title: "Notes", content: .text("hello"))
        #expect(engine.render(panel, width: 12, height: 4) == [
            "┌ Notes ───┐", "│hello     │", "│          │", "└──────────┘"
        ])
        #expect(engine.render(panel, width: 1, height: 3) == ["┌", "│", "└"])
        #expect(engine.render(panel, width: 2, height: 2) == ["┌┐", "└┘"])
        #expect(engine.render(panel, width: 6, height: 1) == ["┌ Not┐"])
        #expect(engine.render(.divider(), width: 4, height: 1) == ["────"])
    }

    @Test func listFocusIsDistinctFromSelection() {
        let engine = UIEngine()
        let list = Element.list(id: "list", rows: [ListRow(id: "one", title: "One")], selection: "one")
        let view = Element.column([
            .panel(title: "Items", content: list).height(.fixed(3)),
            .button("Next", id: "next")
        ])
        let focused = engine.render(view, width: 14, height: 4)
        #expect(focused[0].contains(">Items"))
        #expect(focused[1].contains("> One"))
        _ = engine.handle(.tab, in: view)
        let unfocused = engine.render(view, width: 14, height: 4)
        #expect(!unfocused[0].contains(">Items"))
        #expect(unfocused[1].contains("• One"))
        let empty = Element.list(id: "empty", rows: [], selection: nil)
        #expect(UIEngine().render(empty, width: 12, height: 1)[0].hasPrefix("> (empty)"))
    }

    @Test func textCannotInjectTerminalControls() {
        let engine = UIEngine()
        let frame = engine.render(.text("A\u{1b}[2J\u{1b}]52;c;secret\u{7}B"), width: 80, height: 1)
        #expect(!frame.joined().contains("\u{1b}"))
        #expect(!frame.joined().contains("\u{7}"))
    }

    @Test func tabAndActivationFollowFocus() {
        let engine = UIEngine()
        let view = Element.column(spacing: 0, [
            .button("First", id: "first"),
            .button("Second", id: "second")
        ])
        _ = engine.render(view, width: 30, height: 4)
        #expect(engine.focusedID == "first")
        #expect(engine.handle(.tab, in: view) == nil)
        #expect(engine.focusedID == "second")
        #expect(engine.handle(.enter, in: view) == .activated("second"))
        #expect(engine.handle(.backTab, in: view) == nil)
        #expect(engine.focusedID == "first")
    }

    @Test func editorConsumesPasteAsText() {
        let engine = UIEngine()
        let view = Element.column(spacing: 0, [
            .textEditor(id: "draft", value: "", placeholder: ""),
            .button("Submit", id: "submit")
        ])
        _ = engine.render(view, width: 30, height: 5)
        #expect(engine.handle(.paste("hello\nworld"), in: view) == .textChanged("draft", "hello\nworld"))
        #expect(engine.focusedID == "draft")
    }

    @Test func dialogTrapsFocusAndEscapeRequestsDismissal() {
        let engine = UIEngine()
        let view = Element.button("Outside", id: "outside").overlay(
            .dialog(id: "confirm", title: "Confirm", content: .button("Cancel", id: "cancel"))
        )
        _ = engine.render(view, width: 40, height: 10)
        #expect(engine.focusedID == "cancel")
        _ = engine.handle(.tab, in: view)
        #expect(engine.focusedID == "cancel")
        #expect(engine.handle(.escape, in: view) == .dismissRequested("confirm"))
    }
}
