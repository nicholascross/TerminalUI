@testable import LayoutDemoSupport
import TerminalUIComponents
import Testing

@MainActor
struct LayoutNavigationTests {
    @discardableResult
    private func send(_ key: KeyEvent, app: LayoutApplication, engine: UIEngine) -> UIAction? {
        let action = engine.handle(key, in: app.presentation.resolve())
        if let action { app.presentation.handle(action) }
        return action
    }

    private func focus(_ control: String, app: LayoutApplication, engine: UIEngine) throws {
        let target = try #require(app.target(control))
        #expect(engine.focus(target.engineID, in: app.presentation.resolve()))
    }

    private func screen(_ app: LayoutApplication, engine: UIEngine) -> String {
        engine.render(app.presentation.resolve(), width: 80, height: 24).joined(separator: "\n")
    }

    @Test func viewModelCommandsHaveNoTerminalDependency() {
        var model = LayoutViewModel()
        model.submit("hello")
        #expect(model.status == "Submitted 5 characters")
        model.openCommands()
        #expect(model.commandsOpen)
        #expect(model.activatePane("pane.inspector") == "inspector")
        #expect(model.status == "Focus: Inspector")
        #expect(!model.commandsOpen)
        #expect(model.activatePane("unknown") == nil)
    }

    @Test func enterSubmitsWhileShiftEnterAndPasteRemainMultilineInput() throws {
        let app = LayoutApplication()
        let engine = UIEngine()
        try focus("command", app: app, engine: engine)
        send(.paste("first"), app: app, engine: engine)
        send(.shiftEnter, app: app, engine: engine)
        send(.paste("second\nthird"), app: app, engine: engine)
        #expect(screen(app, engine: engine).contains("Ready"))
        #expect(send(.controlD, app: app, engine: engine) == .unhandledKey(.controlD))
        send(.enter, app: app, engine: engine)
        #expect(screen(app, engine: engine).contains("Submitted 18 characters"))
        let rendered = engine.render(app.presentation.resolve(), width: 80, height: 24).joined(separator: "\n")
        #expect(rendered.contains("Type a multiline command"))
    }

    @Test func shortcutsReachEveryPaneWhileDraftSurvivesParentRefresh() throws {
        let app = LayoutApplication()
        let engine = UIEngine()
        try focus("command", app: app, engine: engine)
        send(.paste("Keep this draft"), app: app, engine: engine)
        for (number, control) in zip("123", ["topics", "inspector", "command"]) {
            try focus("command", app: app, engine: engine)
            for key in [KeyEvent.altCharacter(number), .controlCharacter(number)] {
                #expect(send(key, app: app, engine: engine) == .activated("pane." + control))
                #expect(app.host.focusedID == app.target(control)?.engineID)
            }
        }
        try focus("command", app: app, engine: engine)
        send(.character("1"), app: app, engine: engine)
        send(.paste("23"), app: app, engine: engine)
        send(.enter, app: app, engine: engine)
        #expect(screen(app, engine: engine).contains("Submitted 18 characters"))
    }

    @Test func commandMenuScopesShortcutsDismissesAndFocusesItsDestination() throws {
        let app = LayoutApplication()
        let engine = UIEngine()
        try focus("command", app: app, engine: engine)
        #expect(send(.controlP, app: app, engine: engine) == .activated("commands"))
        let target = try #require(app.target("topics"))
        #expect(!engine.focus(target.engineID, in: app.presentation.resolve()))
        #expect(send(.altCharacter("1"), app: app, engine: engine) != .activated("pane.topics"))
        send(.escape, app: app, engine: engine)
        #expect(!screen(app, engine: engine).contains("Layout commands"))
        send(.controlP, app: app, engine: engine)
        send(.paste("Inspector"), app: app, engine: engine)
        #expect(send(.enter, app: app, engine: engine) == .activated("pane.inspector"))
        #expect(!screen(app, engine: engine).contains("Layout commands"))
        #expect(app.host.focusedID == app.target("inspector")?.engineID)
        #expect(screen(app, engine: engine).contains("Focus: Inspector"))
    }

    @Test func menuBarSupportsBoundKeyboardNavigationAndActivation() throws {
        let app = LayoutApplication()
        let engine = UIEngine()
        let target = try #require(app.presentation.focusTarget(key: "navigation", id: "navigation"))
        #expect(engine.focus(target.engineID, in: app.presentation.resolve()))
        send(.right, app: app, engine: engine)

        #expect(send(.enter, app: app, engine: engine) == .activated("pane.inspector"))
        #expect(app.host.focusedID == app.target("inspector")?.engineID)
    }
}
