import Foundation
import TerminalUI
@testable import TerminalUIRendering
@testable import TerminalUIRuntime
import Testing

@MainActor
struct TerminalHostLatencyTests {
    @Test func `measure scroll input to output with a retained document`() throws {
        let engine = UIEngine()
        let host = TerminalHost(engine: engine)
        let app = LatencyApplication()
        let size = TerminalSize(columns: 80, rows: 24)
        var encoder = FrameEncoder(capability: .none)
        var decoder = InputDecoder()
        _ = try encoder.prepare(#require(host.renderIfNeeded(app, size: size)))
        encoder.commit()
        let layoutCount = engine.textLayoutCount
        let clock = ContinuousClock()
        var samples: [Duration] = []
        for index in 0 ..< 40 {
            let input: [UInt8] = index.isMultiple(of: 2) ? [27, 91, 66] : [27, 91, 65]
            var output: [UInt8] = []
            let started = clock.now
            for event in decoder.feed(input) {
                host.handleInput(event, application: app)
            }
            let frame = try #require(host.renderIfNeeded(app, size: size))
            let bytes = Array(encoder.prepare(frame).utf8)
            try TerminalOutputWriter().writeAll(bytes, write: { remaining in
                output.append(contentsOf: remaining)
                return remaining.count
            }, error: { 0 }, waitWritable: { true })
            encoder.commit()
            samples.append(started.duration(to: clock.now))
            #expect(!output.isEmpty)
            #expect(output == bytes)
            #expect(frame.lines[0].hasPrefix(index.isMultiple(of: 2) ? "Entry 1" : "Entry 0"))
            #expect(app.viewCalls == 1)
            #expect(engine.textLayoutCount == layoutCount)
        }
        samples.sort()
        // Report timings without environment-sensitive performance assertions. This includes decoding,
        // dispatch, painting, encoding and a memory sink; terminal scheduling and I/O are excluded.
        print("Scroll input-to-output (memory sink, 500 entries, 80x24, \(samples.count) samples): "
            + "median \(samples[samples.count / 2]), p95 \(samples[samples.count * 95 / 100 - 1]); additional view calls: \(app.viewCalls - 1)")
    }
}

@MainActor
private final class LatencyApplication: TerminalApplication {
    var viewCalls = 0

    func view() -> Element {
        viewCalls += 1
        return .scrollView(id: "document", content: .column((0 ..< 500).map {
            .paragraph("Entry \($0): worksheet content with 界 and styled text.")
        }))
    }

    func handle(_: UIAction) {
        Issue.record("Scroll-only input unexpectedly delivered an application action")
    }
}
