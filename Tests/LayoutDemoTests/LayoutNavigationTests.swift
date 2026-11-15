@testable import LayoutDemoSupport
@testable import TerminalUI
import TerminalUIEngine
import TerminalUIBridge
@testable import TerminalUIRuntime
import Testing

@MainActor
struct LayoutNavigationTests {
    private typealias Application = TerminalApp<LayoutScreen>
    private let size = TerminalSize(columns: 80, rows: 24)

    private func makeApplication() -> Application {
        Application(root: LayoutScreen(), configuration: .init(mouseEnabled: true), theme: .dusk())
    }

    private func navigation(_ app: Application) -> LayoutNavigation {
        LayoutNavigation(application: app.context)
    }

    private func send(_ key: KeyEvent, app: Application) {
        app.host.handleInput(key, source: app.presentation)
    }

    private func focus(_ pane: Pane, app: Application) {
        #expect(navigation(app).focus(pane))
    }

    private func screen(_ app: Application) -> String {
        app.preview().joined(separator: "\n")
    }

    @Test func `view model commands have no terminal dependency`() {
        var model = LayoutViewModel()
        model.submit("hello")
        #expect(model.status == "Submitted 5 characters")
        model.openCommands()
        #expect(model.commandsOpen)
        model.dismissCommands()
        model.didNavigate(to: .inspector)
        #expect(model.status == "Focus: Inspector")
        #expect(!model.commandsOpen)
        #expect(Pane(actionID: "unknown") == nil)
    }

    @Test func `enter submits while shift enter and paste remain multiline input`() {
        let app = makeApplication()
        focus(.command, app: app)
        send(.paste("first"), app: app)
        send(.shiftEnter, app: app)
        send(.paste("second\nthird"), app: app)
        #expect(screen(app).contains("Ready"))
        send(.controlD, app: app)
        send(.enter, app: app)
        #expect(screen(app).contains("Submitted 18 characters"))
        #expect(screen(app).contains("Type a multiline command"))
    }

    @Test func `shortcuts reach every pane while draft survives parent refresh`() {
        let app = makeApplication()
        focus(.command, app: app)
        send(.paste("Keep this draft"), app: app)
        for pane in Pane.allCases {
            for key in [KeyEvent.altCharacter(pane.shortcut), .controlCharacter(pane.shortcut)] {
                focus(.command, app: app)
                send(key, app: app)
                #expect(app.host.focusedTarget == navigation(app).target(for: pane))
                #expect(screen(app).contains("*\(pane.shortcut) \(pane.title)"))
            }
        }
        focus(.command, app: app)
        send(.character("1"), app: app)
        send(.paste("23"), app: app)
        send(.enter, app: app)
        #expect(screen(app).contains("Submitted 18 characters"))
    }

    @Test func `command menu scopes shortcuts dismisses and focuses its destination`() throws {
        let app = makeApplication()
        focus(.command, app: app)
        send(.controlP, app: app)
        #expect(screen(app).contains("Layout commands"))
        #expect(!navigation(app).focus(.topics))
        send(.altCharacter("1"), app: app)
        #expect(screen(app).contains("Layout commands"))
        send(.escape, app: app)
        let restored = try #require(app.host.renderIfNeeded(app.presentation, size: size))
        #expect(!restored.lines.joined(separator: "\n").contains("Layout commands"))
        #expect(app.host.focusedTarget == navigation(app).target(for: .command))
        #expect(restored.lines[2].contains("*3 Command"))
        send(.controlP, app: app)
        send(.paste("Inspector"), app: app)
        send(.enter, app: app)
        #expect(!screen(app).contains("Layout commands"))
        #expect(app.host.focusedTarget == navigation(app).target(for: .inspector))
        #expect(screen(app).contains("Focus: Inspector"))
        #expect(screen(app).contains("*2 Inspector"))
    }

    @Test func `menu bar supports bound keyboard navigation and activation`() throws {
        let app = makeApplication()
        let target = try #require(app.presentation.focusTarget(key: "navigation", id: "navigation"))
        #expect(app.host.focus(target, in: app.presentation))
        send(.right, app: app)
        send(.enter, app: app)
        #expect(app.host.focusedTarget == navigation(app).target(for: .inspector))
        #expect(screen(app).contains("*2 Inspector"))
    }

    @Test func `toolbar tracks programmatic keyboard and pointer focus in the same frame`() throws {
        let app = makeApplication()
        focus(.topics, app: app)
        let initial = try #require(app.host.renderIfNeeded(app.presentation, size: size))
        #expect(initial.lines[2].contains("*1 Topics"))
        send(.tab, app: app)
        let keyboard = try #require(app.host.renderIfNeeded(app.presentation, size: size))
        #expect(app.host.focusedTarget == navigation(app).target(for: .inspector))
        #expect(keyboard.lines[2].contains("*2 Inspector"))
        app.host.handleInput(.mouse(.init(.press, column: 2, row: 5)), source: app.presentation)
        let pointer = try #require(app.host.renderIfNeeded(app.presentation, size: size))
        #expect(app.host.focusedTarget == navigation(app).target(for: .topics))
        #expect(pointer.lines[2].contains("*1 Topics"))
    }
}
