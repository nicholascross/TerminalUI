import TerminalUI
@testable import TerminalUIRuntime
import Testing

@MainActor
struct MouseHostTests {
    @Test func `resize before click uses new dimensions before output is painted`() throws {
        let host = TerminalHost(configuration: .init(mouseEnabled: true))
        let app = MouseTestApplication()
        app.makeView = {
            .row([.button("L", id: "left").width(.fill()), .button("R", id: "right").width(.fill())])
        }
        _ = try #require(host.renderIfNeeded(app, size: .init(columns: 20, rows: 1)))
        host.deliver(.resized(.init(columns: 10, rows: 1)), to: app)
        host.handleInput(.mouse(.init(.press, column: 7, row: 0)), application: app)
        host.handleInput(.mouse(.init(.release, column: 7, row: 0)), application: app)
        #expect(app.actions == [.resized(.init(columns: 10, rows: 1)), .activated("right")])
        #expect(host.focusedID == "right")
        #expect(try #require(host.renderIfNeeded(app, size: .init(columns: 10, rows: 1))).lines[0].contains(">[R]"))
    }

    @Test func `opening modal in batch blocks the old button and does not reuse its press`() throws {
        let host = TerminalHost(configuration: .init(mouseEnabled: true))
        let app = MouseTestApplication()
        var open = false
        app.makeView = {
            Element.column([.button("Open", id: "open"), .button("Under", id: "under")]).overlay(
                open ? .dialog(id: "modal", title: "Modal", content: .button("Close", id: "close")) : nil,
            )
        }
        app.onAction = { if $0 == .activated("open") { open = true } }
        _ = try #require(host.renderIfNeeded(app, size: .init(columns: 20, rows: 5)))
        host.handleInput(.mouse(.init(.press, column: 2, row: 0)), application: app)
        host.handleInput(.mouse(.init(.release, column: 2, row: 0)), application: app)
        host.handleInput(.mouse(.init(.release, column: 2, row: 1)), application: app)
        #expect(app.actions == [.activated("open")])
        #expect(host.focusedID == "close")
    }

    @Test func `actions rebuild geometry before next mouse in the same batch`() throws {
        let host = TerminalHost(configuration: .init(mouseEnabled: true))
        let app = MouseTestApplication()
        var expanded = false
        var value = "abc"
        app.makeView = {
            .column([
                .text("extra").height(.fixed(2)).visible(expanded),
                .button("Expand", id: "expand"),
                .textField(id: "field", value: value),
            ])
        }
        app.onAction = { action in
            if action == .activated("expand") { expanded = true }
            if case let .textChanged("field", text) = action { value = text }
        }
        let size = TerminalSize(columns: 20, rows: 6)
        _ = try #require(host.renderIfNeeded(app, size: size))
        host.handleInput(.mouse(.init(.press, column: 2, row: 0)), application: app)
        host.handleInput(.mouse(.init(.release, column: 2, row: 0)), application: app)
        host.handleInput(.mouse(.init(.press, column: 0, row: 3)), application: app)
        host.handleInput(.character("!"), application: app)
        let frame = try #require(host.renderIfNeeded(app, size: size))
        #expect(app.actions == [.activated("expand"), .textChanged("field", "!abc")])
        #expect(frame.lines[3].hasPrefix("!abc"))
        #expect(host.focusedID == "field")
    }

    @Test func `wheel then click in same batch uses new viewport and keeps pending output`() throws {
        let host = TerminalHost(configuration: .init(mouseEnabled: true))
        let app = MouseTestApplication()
        app.makeView = {
            .scrollView(id: "scroll", content: .column([
                .paragraph("one\ntwo\nthree"),
                .button("Go", id: "go"),
                .paragraph("five\nsix\nseven\neight"),
            ]))
        }
        let size = TerminalSize(columns: 20, rows: 3)
        _ = try #require(host.renderIfNeeded(app, size: size))
        host.handleInput(.mouse(.init(.scrollDown, column: 2, row: 1)), application: app)
        #expect(app.viewCalls == 1)
        host.handleInput(.mouse(.init(.press, column: 2, row: 0)), application: app)
        host.handleInput(.mouse(.init(.release, column: 2, row: 0)), application: app)
        #expect(app.actions == [.activated("go")])
        #expect(try #require(host.renderIfNeeded(app, size: size)).lines[0].contains("[Go]"))
    }

    @Test func `retained wheel painting preserves unrelated widgets and view calls`() throws {
        let engine = UIEngine()
        let host = TerminalHost(configuration: .init(mouseEnabled: true), engine: engine)
        let probe = MouseDrawProbe()
        let app = MouseTestApplication()
        app.makeView = {
            .row([
                .scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour\nfive\nsix")).width(.fixed(10)),
                .custom(MouseProbeWidget(probe: probe)).width(.fixed(10)),
            ])
        }
        let size = TerminalSize(columns: 20, rows: 3)
        _ = try #require(host.renderIfNeeded(app, size: size))
        let drawings = probe.drawings
        host.handleInput(.mouse(.init(.scrollDown, column: 2, row: 1)), application: app)
        let frame = try #require(host.renderIfNeeded(app, size: size))
        #expect(frame.lines[0].hasPrefix("four      widget"))
        #expect(app.viewCalls == 1)
        #expect(probe.drawings == drawings)
        #expect(app.actions.isEmpty)
    }

    @Test func `mouse is opt in and custom widget receives clipped local coordinates`() throws {
        let disabledHost = TerminalHost()
        let disabledApp = MouseTestApplication()
        disabledApp.makeView = { .button("Go", id: "go") }
        let size = TerminalSize(columns: 20, rows: 4)
        _ = try #require(disabledHost.renderIfNeeded(disabledApp, size: size))
        disabledHost.handleInput(.mouse(.init(.press, column: 2, row: 0)), application: disabledApp)
        disabledHost.handleInput(.mouse(.init(.release, column: 2, row: 0)), application: disabledApp)
        #expect(disabledApp.actions.isEmpty)
        #expect(disabledHost.renderIfNeeded(disabledApp, size: size) == nil)

        let host = TerminalHost(configuration: .init(mouseEnabled: true))
        let probe = MouseDrawProbe()
        let app = MouseTestApplication()
        app.makeView = { .panel(title: "Panel", content: .custom(MouseProbeWidget(probe: probe))) }
        _ = try #require(host.renderIfNeeded(app, size: size))
        host.handleInput(.mouse(.init(.press, column: 4, row: 2)), application: app)
        #expect(probe.events == [.init(.press, column: 3, row: 1)])
        #expect(probe.size == .init(width: 18, height: 2))
        #expect(app.actions == [.activated("custom")])
    }
}

@MainActor
private final class MouseTestApplication: TerminalApplication {
    var makeView: () -> Element = { .text("") }
    var onAction: (UIAction) -> Void = { _ in }
    var actions: [UIAction] = []
    var viewCalls = 0

    func view() -> Element {
        viewCalls += 1; return makeView()
    }

    func handle(_ action: UIAction) {
        actions.append(action); onAction(action)
    }
}

private final class MouseDrawProbe {
    var drawings = 0
    var events: [MouseEvent] = []
    var size: WidgetSize?
}

private struct MouseProbeWidget: CustomWidget {
    let id: String? = "probe"
    let probe: MouseDrawProbe

    func measure(width: Int) -> WidgetSize {
        .init(width: width, height: 2)
    }

    func draw(in canvas: inout Canvas, focused _: Bool) {
        probe.drawings += 1
        canvas.write("widget", x: 0, y: 0)
    }

    func respond(to mouse: MouseEvent, context: WidgetMouseContext) -> WidgetResponse {
        probe.events.append(mouse)
        probe.size = context.size
        return .action(.activated("custom"))
    }
}
