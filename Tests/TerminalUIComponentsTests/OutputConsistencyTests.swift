@testable import TerminalUI
import TerminalUIEngine
import TerminalUIBridge
@testable import TerminalUIRuntime
import Testing

@MainActor
private final class OutputProbe { var text: Binding<String>? }

@TerminalComponent
private struct OutputView: TerminalView {
    @State private var text = "before"
    let probe: OutputProbe
    var body: some TerminalView {
        probe.text = $text; return TerminalUI.Text(text)
    }
}

private actor OutputGate {
    var started = false
    var pending: CheckedContinuation<Void, Never>?
    var bytes: [UInt8] = []
    func write(_ bytes: [UInt8]) async {
        self.bytes = bytes; started = true
        await withCheckedContinuation { pending = $0 }
    }

    func finish() {
        pending?.resume(); pending = nil
    }
}

@MainActor
struct OutputConsistencyTests {
    @Test func `writes during awaited output remain pending for the next immutable frame`() async throws {
        let probe = OutputProbe()
        let app = ComponentApplication(root: OutputView(probe: probe), schedule: { _ in })
        let host = TerminalHost()
        let size = TerminalSize(columns: 20, rows: 2)
        let snapshot = try #require(host.renderIfNeeded(app, size: size))
        let gate = OutputGate()
        let output = Task {
            var writer = TerminalFrameWriter(encoder: FrameEncoder(capability: .none)) { bytes in await gate.write(bytes) }
            try await writer.writeFrame(snapshot)
        }
        while await !(gate.started) {
            await Task.yield()
        }
        probe.text?.wrappedValue = "after"
        #expect(snapshot.lines[0].hasPrefix("before"))
        await gate.finish()
        try await output.value
        let next = try #require(host.renderIfNeeded(app, size: size))
        #expect(next.lines[0].hasPrefix("after"))
        #expect(host.renderIfNeeded(app, size: size) == nil)
    }
}
