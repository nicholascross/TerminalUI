@testable import TerminalUI
import TerminalUIEngine
import TerminalUIBridge
@testable import TerminalUIRuntime
import Testing

@MainActor
private final class ApplicationProbe {
    var context: TerminalApplicationContext?
    var bodies = 0
}

@TerminalComponent
private struct ApplicationScreen: TerminalView {
    @ApplicationContext private var application
    let probe: ApplicationProbe

    var body: some TerminalView {
        probe.context = application
        probe.bodies += 1
        return Column {
            TerminalUI.Button("Quit", id: "quit").onActivate { application.stop() }
            TerminalUI.TextField(id: "draft", text: .constant("Hello"))
        }
    }
}

private struct PlainScreen: TerminalView {
    var body: some TerminalView {
        TerminalUI.Text("Default application")
    }
}

@TerminalApplication
private struct DefaultApplication {
    var root: some TerminalView {
        PlainScreen()
    }
}

@TerminalApplication
private struct ConfiguredApplication {
    let probe: ApplicationProbe

    init(probe: ApplicationProbe = ApplicationProbe()) {
        self.probe = probe
    }

    var root: some TerminalView {
        ApplicationScreen(probe: probe)
    }

    var theme: Theme {
        .dusk()
    }

    var configuration: TerminalConfiguration {
        .init(mouseEnabled: true)
    }
}

@MainActor
struct ApplicationTests {
    @Test func `declarative application defaults preview without terminal access`() {
        let definition = DefaultApplication()
        #expect(!definition.configuration.mouseEnabled)
        let app = definition.makeApplication()
        let frame = app.preview()
        #expect(frame.count == 24)
        #expect(frame.allSatisfy { $0.count == 80 })
        #expect(frame[0].hasPrefix("Default application"))
        #expect(app.host.frameWriteCount == 0)
        #expect(app.preview(width: 12, height: 3)[0] == "Default app…")
    }

    @Test func `runner connects lazily and preview shares host focus`() throws {
        let probe = ApplicationProbe()
        let app = ConfiguredApplication(probe: probe).makeApplication()
        #expect(probe.bodies == 0)
        #expect(app.host.theme.normal == Theme.dusk().normal)
        #expect(app.host.theme.borders.topLeft == Theme.dusk().borders.topLeft)
        let draft = try #require(app.context.focusTarget(id: "draft"))
        let context = try #require(probe.context)
        #expect(context.focus(draft))
        #expect(app.host.focusedTarget == draft)
        let frame = app.preview(width: 30, height: 4)
        #expect(frame[0].contains("Quit"))
        #expect(app.host.focusedTarget == draft)
        #expect(context.focusTarget(id: "draft") == draft)
    }

    @Test func `mounted context uses reconnected services and local quit callback`() throws {
        let probe = ApplicationProbe()
        let presentation = ComponentApplication(root: ApplicationScreen(probe: probe), schedule: { _ in })
        var firstStops = 0
        var secondStops = 0
        presentation.connect(.init(stop: { firstStops += 1 }))
        let engine = UIEngine()
        let root = presentation.resolve()
        let context = try #require(probe.context)
        context.stop()
        presentation.connect(.init(stop: { secondStops += 1 }))
        // A context captured during the first body must use the current host services.
        context.stop()
        let quit = try #require(context.focusTarget(id: "quit"))
        #expect(engine.focus(quit.engineID, in: root))
        try presentation.handle(#require(engine.handle(.enter, in: root)))
        #expect(firstStops == 1)
        #expect(secondStops == 2)
    }

    @Test func `contexts stay isolated and do not retain their applications`() throws {
        let probe = ApplicationProbe()
        var app: TerminalApp<ApplicationScreen>? = TerminalApp(root: ApplicationScreen(probe: probe))
        weak let presentation = app?.presentation
        let target = try #require(app?.context.focusTarget(id: "draft"))
        let context = try #require(probe.context)
        let other = TerminalApp(root: ApplicationScreen(probe: ApplicationProbe()))
        #expect(other.context.focusTarget(id: "draft") != target)
        #expect(!other.context.focus(target))
        app = nil
        #expect(presentation == nil)
        #expect(context.focusTarget(id: "draft") == nil)
        #expect(!context.focus(target))
        context.stop()
    }

    @Test func `configuration override enables pointer input`() {
        let app = ConfiguredApplication().makeApplication()
        _ = app.preview(width: 30, height: 4)
        let draft = app.context.focusTarget(id: "draft")
        app.host.handleInput(.mouse(.init(.press, column: 2, row: 1)), source: app.presentation)
        #expect(app.host.focusedTarget == draft)
    }
}
