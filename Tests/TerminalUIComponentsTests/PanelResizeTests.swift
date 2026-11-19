import TerminalUI
import Testing

@MainActor
struct ComponentPanelResizeTests {
    @Test func `component instances keep separate sizes for the same local panel ID`() {
        let harness = ApplicationHarness(root: Column {
            PanelPair(title: "First")
            PanelPair(title: "Second")
        }, configuration: .init(mouseEnabled: true, mouseDragEnabled: true))

        func edges() -> [Int?] {
            let frame = harness.preview(width: 32, height: 8)
            return [0, 4].map { Array(frame[$0]).firstIndex(of: "┐") }
        }

        #expect(edges() == [11, 11])
        harness.send(.mouse(.init(.press, column: 11, row: 1)))
        harness.send(.mouse(.init(.release, column: 15, row: 1)))
        #expect(edges() == [15, 11])
        harness.invalidate()
        #expect(edges() == [15, 11])
    }
}

@TerminalComponent
private struct PanelPair: TerminalView {
    let title: String

    var body: some TerminalView {
        Row {
            WrappedPanel(title: title).resizable(id: "files", edge: .trailing, minimum: 8, preferredSize: 12)
            Text("Details").layoutSizing(width: .flexible(minimum: 8))
        }.height(.fixed(4))
    }
}

@TerminalComponent
private struct WrappedPanel: TerminalView {
    let title: String

    var body: some TerminalView {
        Panel(title) { Text("files") }.layoutSizing(height: .flexible())
    }
}
