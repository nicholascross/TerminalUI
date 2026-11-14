import TerminalUI
import Testing

struct GlobalMenuShortcutTests {
    private func bar(_ items: [MenuItem], id: String = "bar") -> Element {
        .menuBar(id: id, items: items, selection: nil)
    }

    private var navigation: Element {
        bar([MenuItem(id: "files", title: "Files", shortcut: "1",
                      globalShortcuts: [.altCharacter("1"), .controlCharacter("1")])])
    }

    @Test func globalShortcutsActivateWithoutMovingFocusOrChangingEditorSelection() {
        let engine = UIEngine()
        let root = Element.column([.textEditor(id: "draft", value: "draft"), navigation])
        #expect(engine.focus("draft", in: root))
        _ = engine.handle(.shiftLeft, in: root)
        for key: KeyEvent in [.altCharacter("1"), .controlCharacter("1")] {
            #expect(engine.handle(key, in: root) == .activated("files"))
            #expect(engine.focusedID == "draft")
        }
        #expect(engine.handle(.character("!"), in: root) == .textChanged("draft", "draf!"))
        #expect(engine.handle(.character("1"), in: root) == .textChanged("draft", "draft1"))
        #expect(engine.handle(.paste("1234"), in: root) == .textChanged("draft", "draft1234"))
    }

    @Test func disabledHiddenRemovedAndUnavailableMenusCannotActivate() {
        let engine = UIEngine()
        let draft = Element.textField(id: "draft", value: "")
        for menu in [navigation.enabled(false), navigation.visible(false),
                     Element.panel(title: "Disabled", content: navigation).enabled(false), .text("Removed")] {
            let root = Element.column([draft, menu])
            #expect(engine.handle(.altCharacter("1"), in: root) == .unhandledKey(.altCharacter("1")))
        }
        let unavailable = bar([MenuItem(id: "files", title: "Files", unavailableReason: "Wait",
                                        globalShortcuts: [.altCharacter("1")])])
        let root = Element.column([draft, unavailable, navigation])
        // An unavailable match consumes the key; it cannot fall through to another destination.
        #expect(engine.handle(.altCharacter("1"), in: root) == nil)
        #expect(engine.handle(.altCharacter("1"), in: .column([draft, navigation])) == .activated("files"))
    }

    @Test func dialogsScopeShortcutsAndRestoreWorkspaceBindingsOnDismissal() {
        let engine = UIEngine()
        let workspace = Element.column([.textField(id: "draft", value: ""), navigation])
        let modal = workspace.overlay(.dialog(id: "dialog", title: "Dialog", content: .column([
            .textField(id: "inside", value: ""),
            bar([MenuItem(id: "local", title: "Local", globalShortcuts: [.altCharacter("2")])], id: "local.bar")
        ])))
        #expect(engine.handle(.altCharacter("1"), in: modal) == .unhandledKey(.altCharacter("1")))
        #expect(engine.handle(.altCharacter("2"), in: modal) == .activated("local"))
        #expect(engine.focusedID == "inside")
        #expect(engine.handle(.altCharacter("2"), in: .column([modal]).enabled(false)) == .unhandledKey(.altCharacter("2")))
        #expect(engine.handle(.escape, in: modal) == .dismissRequested("dialog"))
        #expect(engine.handle(.altCharacter("1"), in: workspace) == .activated("files"))
        #expect(engine.focusedID == "draft")
    }

    @Test func searchableMenuRegistersOnlyMatchingResultsAndConsumesUnavailableShortcuts() {
        let engine = UIEngine()
        let items = [MenuItem(id: "files", title: "Files", globalShortcuts: [.altCharacter("1")]),
                     MenuItem(id: "push", title: "Push", unavailableReason: "No remote",
                              globalShortcuts: [.altCharacter("2")])]
        func menu(_ query: String) -> Element {
            .menu(id: "menu", title: "Commands", items: items, query: query, selection: nil)
        }
        #expect(engine.handle(.altCharacter("1"), in: menu("")) == .activated("files"))
        #expect(engine.handle(.altCharacter("2"), in: menu("")) == nil)
        #expect(engine.handle(.altCharacter("1"), in: menu("Push")) == .unhandledKey(.altCharacter("1")))
        #expect(engine.handle(.altCharacter("1"), in: menu("No matches")) == .unhandledKey(.altCharacter("1")))
    }

    @Test func globalsPrecedeFocusedBindingsAndResolveDuplicatesInTreeOrder() {
        let engine = UIEngine()
        let root = Element.column([
            .textField(id: "draft", value: "").onKey(.altCharacter("1"), activate: "local"),
            navigation,
            bar([MenuItem(id: "second", title: "Second", globalShortcuts: [.altCharacter("1")])], id: "second.bar")
        ])
        #expect(engine.handle(.altCharacter("1"), in: root) == .activated("files"))
        #expect(engine.focusedID == "draft")
    }

    @Test func globalsNeverCaptureTypingPasteTraversalOrDialogEscape() {
        let engine = UIEngine()
        let invalid = bar([MenuItem(id: "invalid", title: "Invalid", globalShortcuts:
            [.character("1"), .paste("1"), .tab, .escape, .enter])])
        let root = Element.column([.textField(id: "draft", value: ""), invalid])
        #expect(engine.handle(.character("1"), in: root) == .textChanged("draft", "1"))
        #expect(engine.handle(.paste("1"), in: root) == .textChanged("draft", "1"))
        #expect(engine.handle(.tab, in: root) == nil)
        #expect(engine.focusedID == "bar")
        let modal = root.overlay(.dialog(id: "modal", title: "Modal", content: invalid))
        #expect(engine.handle(.escape, in: modal) == .dismissRequested("modal"))
    }

    @Test func dedicatedControlKeysAndMouseShareTheDeclaredAction() {
        let engine = UIEngine()
        let menu = bar([MenuItem(id: "commands", title: "Commands", globalShortcuts: [.controlP, .controlD, .controlC])])
        let root = Element.column([.textField(id: "draft", value: ""), menu])
        for key: KeyEvent in [.controlP, .controlD, .controlC] {
            #expect(engine.handle(key, in: root) == .activated("commands"))
        }
        _ = engine.render(root, width: 40, height: 3)
        #expect(engine.handleMouseEvent(.init(.press, column: 4, row: 1)).action == .selectionChanged("bar", "commands"))
        _ = engine.render(root, width: 40, height: 3)
        #expect(engine.handleMouseEvent(.init(.release, column: 4, row: 1)).action == .activated("commands"))
    }
}
