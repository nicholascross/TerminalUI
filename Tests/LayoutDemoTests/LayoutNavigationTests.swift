@testable import LayoutDemo
import TerminalUILayout
import Testing

@MainActor
struct LayoutNavigationTests {
    @Test func enterSubmitsWhileShiftEnterAndPasteRemainMultilineInput() throws {
        let app = LayoutApplication()
        app.draft = "first"
        let engine = UIEngine()
        #expect(engine.focus("command", in: app.view()))

        let newline = try #require(engine.handle(.shiftEnter, in: app.view()))
        #expect(newline == .textChanged("command", "first\n"))
        app.handle(newline)
        let paste = try #require(engine.handle(.paste("second\nthird"), in: app.view()))
        #expect(paste == .textChanged("command", "first\nsecond\nthird"))
        app.handle(paste)
        #expect(app.status == "Ready")
        #expect(engine.handle(.controlD, in: app.view()) == .unhandledKey(.controlD))
        #expect(app.draft == "first\nsecond\nthird")

        let submit = try #require(engine.handle(.enter, in: app.view()))
        #expect(submit == .activated("submit"))
        app.handle(submit)
        #expect(app.draft.isEmpty)
        #expect(app.status == "Submitted 18 characters")
    }

    @Test func shortcutsReachEveryPaneWhileTheEditorHasFocus() {
        let app = LayoutApplication()
        app.draft = "Keep this draft"
        let engine = UIEngine()
        for (number, control) in zip("123", ["topics", "inspector", "command"]) {
            let root = app.view()
            #expect(engine.focus("command", in: root))
            for key in [KeyEvent.altCharacter(number), .controlCharacter(number)] {
                let action = engine.handle(key, in: root)
                #expect(action == .activated("pane." + control))
                if let action { app.handle(action) }
                #expect(app.host.focusedID == control)
                #expect(app.draft == "Keep this draft")
            }
        }
        #expect(engine.handle(.character("1"), in: app.view()) == .textChanged("command", "Keep this draft1"))
        #expect(engine.handle(.paste("23"), in: app.view()) == .textChanged("command", "Keep this draft23"))
    }

    @Test func commandMenuScopesShortcutsDismissesAndFocusesItsDestination() {
        let app = LayoutApplication()
        app.handle(.activated("pane.command"))
        let engine = UIEngine()
        let root = app.view()
        #expect(engine.focus("command", in: root))
        #expect(engine.handle(.controlP, in: root) == .activated("commands"))
        app.handle(.activated("commands"))
        let modal = app.view()
        #expect(!engine.focus("topics", in: modal))
        #expect(engine.handle(.altCharacter("1"), in: modal) != .activated("pane.topics"))
        #expect(engine.handle(.escape, in: modal) == .dismissRequested("commands"))
        app.handle(.dismissRequested("commands"))
        #expect(!app.commandsOpen)

        app.handle(.activated("commands"))
        app.handle(.textChanged("commands.search", "Inspector"))
        #expect(engine.handle(.enter, in: app.view()) == .activated("pane.inspector"))
        app.handle(.activated("pane.inspector"))
        #expect(!app.commandsOpen)
        #expect(app.host.focusedID == "inspector")
        #expect(app.status == "Focus: Inspector")
    }

    @Test func menuBarSupportsKeyboardNavigationAndActivation() {
        let app = LayoutApplication()
        let engine = UIEngine()
        var root = app.view()
        #expect(engine.focus("navigation", in: root))
        #expect(engine.handle(.right, in: root) == .selectionChanged("navigation", "pane.inspector"))
        app.handle(.selectionChanged("navigation", "pane.inspector"))
        root = app.view()
        #expect(engine.handle(.enter, in: root) == .activated("pane.inspector"))
        app.handle(.activated("pane.inspector"))
        #expect(app.host.focusedID == "inspector")
    }
}
