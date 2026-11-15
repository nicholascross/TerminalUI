import TerminalUICore
import TerminalUIRendering
@testable import TerminalUIRuntime
import Testing

struct TerminalFrameWriterTests {
    @Test func `failed output discards the committed frame before retrying`() async throws {
        let sink = FrameSink()
        var writer = TerminalFrameWriter(encoder: FrameEncoder(capability: .none)) { bytes in
            try await sink.write(bytes)
        }
        var canvas = Canvas(width: 4, height: 1)
        canvas.write("abcd", x: 0, y: 0)
        try await writer.writeFrame(canvas.grid)
        canvas.write("x", x: 1, y: 0)
        await sink.failNextWrite()
        await #expect(throws: FrameSink.Failure.self) { try await writer.writeFrame(canvas.grid) }
        try await writer.writeFrame(canvas.grid)
        try await writer.writeFrame(canvas.grid)
        let attempts = await sink.attempts
        #expect(attempts.count == 4)
        #expect(attempts[1].contains("x"))
        #expect(!attempts[1].contains("a"))
        #expect(attempts[2].contains("axcd"))
        #expect(attempts[3].isEmpty)
    }
}

private actor FrameSink {
    struct Failure: Error {}
    private var shouldFail = false
    private(set) var attempts: [String] = []

    func failNextWrite() {
        shouldFail = true
    }

    func write(_ bytes: [UInt8]) throws {
        attempts.append(String(bytes: bytes, encoding: .utf8) ?? "")
        if shouldFail {
            shouldFail = false
            throw Failure()
        }
    }
}
