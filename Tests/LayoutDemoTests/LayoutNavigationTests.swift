@testable import LayoutDemoSupport
import TerminalUI
import Testing

@MainActor
struct LayoutNavigationTests {
    private typealias Application = ApplicationHarness<LayoutScreen>

    private func makeApplication() -> Application {
        Application(root: LayoutScreen(), configuration: .init(mouseEnabled: true), theme: .dusk())
    }

    private func send(_ key: KeyEvent, app: Application) {
        app.send(key)
    }

    private func focus(_ pane: Pane, app: Application) {
        #expect(app.context.focus(pane))
    }

    private func screen(_ app: Application) -> String {
        app.preview().joined(separator: "\n")
    }

    @Test func `view model updates submission navigation and presentation state`() {
        var model = LayoutViewModel()
        model.submit("hello")
        #expect(model.status == "Submitted 5 characters")
        model.openCommands()
        #expect(model.commandsOpen)
        model.dismissCommands()
        model.didFocus(.inspector)
        #expect(model.status == "Focus: Inspector")
        #expect(!model.commandsOpen)
    }

    @Test func `enter submits while shift enter and paste remain multiline input`() {
        let app = makeApplication()
        focus(.command, app: app)
        send(.paste("first"), app: app)
        send(.shiftEnter, app: app)
        send(.paste("second\nthird"), app: app)
        #expect(screen(app).contains("Focus: Command"))
        send(.controlD, app: app)
        send(.enter, app: app)
        #expect(screen(app).contains("Submitted 18 characters"))
        #expect(screen(app).contains("Type a multiline command"))
    }

    @Test func `shortcuts reach every pane while draft survives parent refresh`() {
        let app = makeApplication()
        focus(.command, app: app)
        send(.paste("Keep this draft"), app: app)
        for (index, pane) in Pane.allCases.enumerated() {
            let shortcut = Character(String(index + 1))
            for key in [KeyEvent.altCharacter(shortcut), .controlCharacter(shortcut)] {
                focus(.command, app: app)
                send(key, app: app)
                #expect(app.focusedTarget == app.context.focusTarget(pane))
                #expect(screen(app).contains("*\(shortcut) \(pane.title)"))
            }
        }
        focus(.command, app: app)
        send(.character("1"), app: app)
        send(.paste("23"), app: app)
        send(.enter, app: app)
        #expect(screen(app).contains("Submitted 18 characters"))
    }

    @Test func `command menu scopes shortcuts dismisses and focuses its destination`() {
        let app = makeApplication()
        focus(.command, app: app)
        send(.controlP, app: app)
        #expect(screen(app).contains("Layout commands"))
        #expect(!app.context.focus(Pane.topics))
        send(.altCharacter("1"), app: app)
        #expect(screen(app).contains("Layout commands"))
        send(.escape, app: app)
        let restored = app.preview()
        #expect(!restored.joined(separator: "\n").contains("Layout commands"))
        #expect(app.focusedTarget == app.context.focusTarget(Pane.command))
        #expect(restored[2].contains("*3 Command"))
        send(.controlP, app: app)
        send(.paste("Inspector"), app: app)
        send(.enter, app: app)
        #expect(!screen(app).contains("Layout commands"))
        #expect(app.focusedTarget == app.context.focusTarget(Pane.inspector))
        #expect(screen(app).contains("Focus: Inspector"))
        #expect(screen(app).contains("*2 Inspector"))
    }

    @Test func `menu bar owns keyboard navigation and invokes typed pane actions`() throws {
        let app = makeApplication()
        let target = try #require(app.context.focusTarget(path: ["navigation"], id: "navigation"))
        #expect(app.context.focus(target))
        send(.right, app: app)
        send(.enter, app: app)
        #expect(app.focusedTarget == app.context.focusTarget(Pane.inspector))
        #expect(screen(app).contains("*2 Inspector"))
    }

    @Test func `demo starts on topics and shows hints for the focused pane`() {
        let app = makeApplication()
        let initial = screen(app)
        #expect(app.focusedTarget == app.context.focusTarget(Pane.topics))
        #expect(initial.contains("↑/↓ select a topic"))
        for pane in Pane.allCases {
            focus(pane, app: app)
            let lines = app.preview(width: 60, height: 18)
            #expect(lines[17].contains("Ctrl-C quit"))
            #expect(lines[17].contains("Alt+1–3 panes"))
            switch pane {
            case .topics: #expect(lines[16].contains("select a topic"))
            case .inspector: #expect(lines[16].contains("PgUp/PgDn page"))
            case .command: #expect(lines[16].contains("Shift+Enter newline"))
            }
        }
        app.invalidate()
        #expect(screen(app).contains("Shift+Enter newline"))
        #expect(app.focusedTarget == app.context.focusTarget(Pane.command))
    }

    @Test func `toolbar tracks programmatic keyboard and pointer focus in the same frame`() {
        let app = makeApplication()
        focus(.topics, app: app)
        let initial = app.preview()
        #expect(initial[2].contains("*1 Topics"))
        send(.tab, app: app)
        let keyboard = app.preview()
        #expect(app.focusedTarget == app.context.focusTarget(Pane.inspector))
        #expect(keyboard[2].contains("*2 Inspector"))
        app.send(.mouse(.init(.press, column: 2, row: 5)))
        let pointer = app.preview()
        #expect(app.focusedTarget == app.context.focusTarget(Pane.topics))
        #expect(pointer[2].contains("*1 Topics"))
    }

    @Test func `topic selection updates inspector and survives screen refresh`() {
        let app = makeApplication()
        focus(.topics, app: app)
        send(.down, app: app)
        #expect(screen(app).contains("Struct components retain local state"))
        focus(.command, app: app)
        send(.paste("Keep this draft"), app: app)
        send(.controlP, app: app)
        send(.paste("Inspector"), app: app)
        send(.enter, app: app)
        app.invalidate()
        #expect(screen(app).contains("Struct components retain local state"))
        #expect(screen(app).contains("Keep this draft"))
    }
}
