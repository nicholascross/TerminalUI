import TerminalUIEngine
import Testing

/// Compiles against the product facade without importing or testing implementation modules.
struct FacadeCompatibilityTests {
    @Test func `qualified types support custom widgets input and encoding`() throws {
        let widget: any TerminalUIEngine.CustomWidget = FacadeWidget()
        let root: TerminalUIEngine.Element = .custom(widget).width(.fill()).height(.fixed(1))
        let engine = TerminalUIEngine.UIEngine()
        #expect(engine.focus("probe", in: root))
        let grid: TerminalUIEngine.CellGrid = engine.renderGrid(root, width: 8, height: 1)
        #expect(grid.lines == ["probe   "])
        var decoder = TerminalUIEngine.InputDecoder()
        let keys: [TerminalUIEngine.KeyEvent] = decoder.feed([13])
        let action: TerminalUIEngine.UIAction? = try engine.handle(#require(keys.first), in: root)
        #expect(action == .activated("probe"))
        var encoder = TerminalUIEngine.FrameEncoder(capability: .none)
        #expect(encoder.prepare(grid).contains("probe"))
        encoder.commit()
        #expect(encoder.prepare(grid).isEmpty)
        encoder.commit()
    }

    @Test @MainActor func `application and host use the existing facade names`() {
        let app: any TerminalUIEngine.TerminalApplication = FacadeApplication()
        let configuration = TerminalUIEngine.TerminalConfiguration(mouseEnabled: true)
        let host = TerminalUIEngine.TerminalHost(configuration: configuration, theme: .terminalNative)
        let root = app.view()
        #expect(host.focus("done", in: root))
        #expect(host.focusedID == "done")
        host.keepVisible("done")
        host.resetState(for: "done")
        #expect(host.focusedID == nil)
        host.stop()
    }
}

private struct FacadeWidget: TerminalUIEngine.CustomWidget {
    let id: String? = "probe"
    let isFocusable = true

    func measure(context: TerminalUIEngine.WidgetMeasureContext) -> TerminalUIEngine.WidgetSize {
        .init(width: min(5, context.width), height: 1)
    }

    func draw(in canvas: inout TerminalUIEngine.Canvas, context: TerminalUIEngine.WidgetDrawContext) {
        canvas.write("probe", x: 0, y: 0, style: context.style)
    }

    func respond(to key: TerminalUIEngine.KeyEvent, context _: TerminalUIEngine.WidgetEventContext) -> TerminalUIEngine.WidgetResponse {
        key == .enter ? .action(.activated("probe")) : .unhandled
    }
}

@MainActor
private final class FacadeApplication: TerminalUIEngine.TerminalApplication {
    func view() -> TerminalUIEngine.Element {
        .button("Done", id: "done")
    }

    func handle(_: TerminalUIEngine.UIAction) {}
}
