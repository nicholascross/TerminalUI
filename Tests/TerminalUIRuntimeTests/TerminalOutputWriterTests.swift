@testable import TerminalUIRuntime
import Testing
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

struct TerminalOutputWriterTests {
    @Test func `handles short writes and interrupted or blocked output`() throws {
        let data = Array("terminal frame".utf8)
        var call = 0
        var lastError: Int32 = 0
        var output: [UInt8] = []
        var waits = 0
        try TerminalOutputWriter().writeAll(data, write: { remaining in
            call += 1
            switch call {
            case 1: lastError = EINTR; return -1
            case 2: lastError = EAGAIN; return -1
            case 3:
                output.append(contentsOf: remaining.prefix(3))
                return 3
            default:
                output.append(contentsOf: remaining)
                return remaining.count
            }
        }, error: { lastError }, waitWritable: { waits += 1; return true })
        #expect(output == data)
        #expect(waits == 1)
    }

    @Test func `reports fatal failure after partial write`() {
        var output: [UInt8] = []
        var call = 0
        #expect(throws: TerminalError.systemCall("write", EIO)) {
            try TerminalOutputWriter().writeAll(Array("frame".utf8), write: { remaining in
                call += 1
                if call == 1 { output.append(contentsOf: remaining.prefix(2)); return 2 }
                return -1
            }, error: { EIO }, waitWritable: { true })
        }
        #expect(output == Array("fr".utf8))
    }

    @Test func `stops after bounded backpressure`() {
        var waits = 0
        #expect(throws: TerminalError.outputUnavailable) {
            try TerminalOutputWriter().writeAll([1], write: { _ in -1 }, error: { EAGAIN }, waitWritable: {
                waits += 1
                return true
            })
        }
        #expect(waits == 20)
    }
}
