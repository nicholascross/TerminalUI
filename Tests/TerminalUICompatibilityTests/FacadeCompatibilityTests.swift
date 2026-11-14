import TerminalUI
import Testing

/// Compiles against the product facade without importing or testing implementation modules.
struct FacadeCompatibilityTests {
    @Test func `qualified types support custom widgets input and encoding`() throws {
        let widget: any TerminalUI.CustomWidget = FacadeWidget()
        let root: TerminalUI.Element = .custom(widget).width(.fill()).height(.fixed(1))
        let engine = TerminalUI.UIEngine()
        #expect(engine.focus("probe", in: root))
        let grid: TerminalUI.CellGrid = engine.renderGrid(root, width: 8, height: 1)
        #expect(grid.lines == ["probe   "])
        var decoder = TerminalUI.InputDecoder()
        let keys: [TerminalUI.KeyEvent] = decoder.feed([13])
        let action: TerminalUI.UIAction? = try engine.handle(#require(keys.first), in: root)
        #expect(action == .activated("probe"))
        var encoder = TerminalUI.FrameEncoder(capability: .none)
        #expect(encoder.prepare(grid).contains("probe"))
        encoder.commit()
        #expect(encoder.prepare(grid).isEmpty)
        encoder.commit()
    }

    @Test @MainActor func `application and host use the existing facade names`() {
        let app: any TerminalUI.TerminalApplication = FacadeApplication()
        let configuration = TerminalUI.TerminalConfiguration(mouseEnabled: true)
        let host = TerminalUI.TerminalHost(configuration: configuration, theme: .terminalNative)
        let root = app.view()
        #expect(host.focus("done", in: root))
        #expect(host.focusedID == "done")
        host.keepVisible("done")
        host.resetState(for: "done")
        #expect(host.focusedID == nil)
        host.stop()
    }
}

private struct FacadeWidget: TerminalUI.CustomWidget {
    let id: String? = "probe"
    let isFocusable = true

    func measure(context: TerminalUI.WidgetMeasureContext) -> TerminalUI.WidgetSize {
        .init(width: min(5, context.width), height: 1)
    }

    func draw(in canvas: inout TerminalUI.Canvas, context: TerminalUI.WidgetDrawContext) {
        canvas.write("probe", x: 0, y: 0, style: context.style)
    }

    func respond(to key: TerminalUI.KeyEvent, context _: TerminalUI.WidgetEventContext) -> TerminalUI.WidgetResponse {
        key == .enter ? .action(.activated("probe")) : .unhandled
    }
}

@MainActor
private final class FacadeApplication: TerminalUI.TerminalApplication {
    func view() -> TerminalUI.Element {
        .button("Done", id: "done")
    }

    func handle(_: TerminalUI.UIAction) {}
}
