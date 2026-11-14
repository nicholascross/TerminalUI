import TerminalUI
@testable import TerminalUIRendering
@testable import TerminalUIRuntime
import Testing

@MainActor
struct TerminalHostRenderingTests {
    private let size = TerminalSize(columns: 20, rows: 2)

    @Test func `scroll keys repaint without view calls or new measurements including at limits`() throws {
        let engine = UIEngine()
        let host = TerminalHost(engine: engine)
        let probe = HostWidgetProbe()
        let root = Element.scrollView(id: "scroll", content: .column([
            .custom(HostMeasuredWidget(probe: probe)),
            .paragraph("one\ntwo\nthree\nfour\nfive"),
        ]))
        let app = HostTestApplication { root }
        let initial = try #require(host.renderIfNeeded(app, size: size))
        #expect(app.viewCalls == 1)
        let measurements = probe.measurements
        let layouts = engine.textLayoutCount
        let cases: [(KeyEvent, [String])] = [
            (.up, ["widget", "one"]), (.home, ["widget", "one"]), (.down, ["one", "two"]),
            (.pageDown, ["three", "four"]), (.end, ["four", "five"]), (.down, ["four", "five"]),
            (.pageUp, ["two", "three"]), (.up, ["one", "two"]), (.home, ["widget", "one"]),
        ]
        for (key, lines) in cases {
            host.handleInput(key, application: app)
            let frame = try #require(host.renderIfNeeded(app, size: size))
            #expect(frame.lines == lines.map { $0 + String(repeating: " ", count: size.columns - $0.count) })
            #expect(app.viewCalls == 1)
            #expect(app.actions.isEmpty)
            #expect(probe.measurements == measurements)
            #expect(engine.textLayoutCount == layouts)
            #expect(host.renderIfNeeded(app, size: size) == nil)
        }
        #expect(host.renderIfNeeded(app, size: size) == nil)
        host.handleInput(.home, application: app)
        #expect(host.renderIfNeeded(app, size: size) == initial)
        host.handleInput(.down, application: app)
        host.handleInput(.down, application: app)
        #expect(try #require(host.renderIfNeeded(app, size: size)).lines[0].hasPrefix("two"))
        #expect(app.viewCalls == 1)
    }

    @Test func `actions and focus rebuild before the next event in a batch`() throws {
        let host = TerminalHost()
        let app = HostTestApplication { .textField(id: "draft", value: "") }
        app.makeView = { .textField(id: "draft", value: app.value) }
        _ = try #require(host.renderIfNeeded(app, size: size))
        host.handleInput(.character("a"), application: app)
        host.handleInput(.character("b"), application: app)
        let frame = try #require(host.renderIfNeeded(app, size: size))
        #expect(app.actions == [.textChanged("draft", "a"), .textChanged("draft", "ab")])
        #expect(frame.lines[0].hasPrefix("ab"))
        #expect(app.viewCalls == 3)

        let focused = HostTestApplication { .text("unused") }
        focused.makeView = {
            .column([
                .scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour")).height(.fixed(2)),
                .button(host.focusedID ?? "none", id: "button"),
            ])
        }
        host.invalidate()
        _ = host.renderIfNeeded(focused, size: TerminalSize(columns: 20, rows: 3))
        host.handleInput(.tab, application: focused)
        host.handleInput(.enter, application: focused)
        let focusedFrame = try #require(host.renderIfNeeded(focused, size: TerminalSize(columns: 20, rows: 3)))
        #expect(focused.actions == [.activated("button")])
        #expect(host.focusedID == "button")
        #expect(focusedFrame.lines[2].hasPrefix(">[button]"))
        #expect(focused.viewCalls == 3)
    }

    @Test func `invalidation resize theme focus visibility and reset rebuild and coalesce`() throws {
        let host = TerminalHost()
        let root = Element.scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour").id("tail"))
        let app = HostTestApplication { root }
        _ = try #require(host.renderIfNeeded(app, size: size))
        host.invalidate()
        host.invalidate()
        host.handleInput(.down, application: app)
        #expect(host.renderIfNeeded(app, size: size)?.lines[0].hasPrefix("two") == true)
        #expect(app.viewCalls == 2)
        let larger = TerminalSize(columns: 24, rows: 3)
        host.deliver(.resized(larger), to: app)
        #expect(host.renderIfNeeded(app, size: larger)?.lines.count == 3)
        #expect(app.viewCalls == 3)
        #expect(app.actions == [.resized(larger)])
        host.theme = .dark
        _ = try #require(host.renderIfNeeded(app, size: larger))
        #expect(app.viewCalls == 4)
        #expect(host.focus("scroll", in: root))
        _ = try #require(host.renderIfNeeded(app, size: larger))
        #expect(app.viewCalls == 5)
        host.keepVisible("tail")
        _ = try #require(host.renderIfNeeded(app, size: larger))
        #expect(app.viewCalls == 6)
        host.resetState(for: "scroll")
        _ = try #require(host.renderIfNeeded(app, size: larger))
        #expect(app.viewCalls == 7)
    }

    @Test func `zero terminal dimensions defer invalidation without losing it`() throws {
        let host = TerminalHost()
        let app = HostTestApplication { .text("ready") }
        #expect(host.renderIfNeeded(app, size: .init(columns: 0, rows: 2)) == nil)
        #expect(host.renderIfNeeded(app, size: .init(columns: 20, rows: 0)) == nil)
        #expect(app.viewCalls == 0)
        #expect(try #require(host.renderIfNeeded(app, size: size)).lines[0].hasPrefix("ready"))
        #expect(app.viewCalls == 1)
    }

    @Test(arguments: [WidgetResponse.consumed, .unhandled, .action(.activated("widget"))])
    func `custom widget input rebuilds live state and measurements`(_ response: WidgetResponse) throws {
        let host = TerminalHost()
        let probe = HostWidgetProbe()
        let app = HostTestApplication {
            .column([
                .custom(HostMeasuredWidget(probe: probe, response: response)),
                .text("tail"),
            ])
        }
        let large = TerminalSize(columns: 20, rows: 5)
        #expect(try #require(host.renderIfNeeded(app, size: large)).lines[1].hasPrefix("tail"))
        let measurements = probe.measurements
        host.handleInput(.down, application: app)
        #expect(try #require(host.renderIfNeeded(app, size: large)).lines[3].hasPrefix("tail"))
        #expect(probe.height == 3)
        #expect(probe.measurements > measurements)
        #expect(app.viewCalls == 2)
        switch response {
        case .consumed: #expect(app.actions.isEmpty)
        case .unhandled: #expect(app.actions == [.unhandledKey(.down)])
        case .action(let action): #expect(app.actions == [action])
        }
    }
}

@MainActor
private final class HostTestApplication: TerminalApplication {
    var makeView: () -> Element
    var viewCalls = 0
    var actions: [UIAction] = []
    var value = ""

    init(_ makeView: @escaping () -> Element) { self.makeView = makeView }

    func view() -> Element {
        viewCalls += 1
        return makeView()
    }

    func handle(_ action: UIAction) {
        actions.append(action)
        if case .textChanged(_, let value) = action { self.value = value }
    }
}

private final class HostWidgetProbe {
    var height = 1
    var measurements = 0
}

private struct HostMeasuredWidget: CustomWidget {
    let id: String? = "widget"
    let isFocusable = true
    let probe: HostWidgetProbe
    var response: WidgetResponse = .consumed

    func measure(width: Int) -> WidgetSize {
        probe.measurements += 1
        return WidgetSize(width: width, height: probe.height)
    }

    func draw(in canvas: inout Canvas, focused: Bool) {
        canvas.write("widget", x: 0, y: 0)
    }

    func respond(to key: KeyEvent, theme: Theme) -> WidgetResponse {
        probe.height = 3
        return response
    }
}
