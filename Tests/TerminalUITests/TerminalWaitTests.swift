import CTerminalSupport
import Testing
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

struct TerminalWaitTests {
    @Test func `read readiness distinguishes terminal input and signal wakeups`() throws {
        var terminal: [Int32] = [0, 0]
        var signals: [Int32] = [0, 0]
        try #require(pipe(&terminal) == 0)
        defer { close(terminal[0]); close(terminal[1]) }
        try #require(pipe(&signals) == 0)
        defer { close(signals[0]); close(signals[1]) }
        #expect(tui_wait_readable(terminal[0], signals[0], 0) == 0)
        var byte: UInt8 = 1
        #expect(write(signals[1], &byte, 1) == 1)
        #expect(tui_wait_readable(terminal[0], signals[0], 0) == 2)
        #expect(write(terminal[1], &byte, 1) == 1)
        #expect(tui_wait_readable(terminal[0], signals[0], 0) == 3)
        #expect(read(signals[0], &byte, 1) == 1)
        #expect(tui_wait_readable(terminal[0], signals[0], 0) == 1)
        #expect(tui_wait_writable(terminal[1], 0) == 1)
    }

    @Test func `application updates use a descriptor independent of process signals`() throws {
        var terminal: [Int32] = [0, 0]
        var signals: [Int32] = [0, 0]
        var updates: [Int32] = [0, 0]
        try #require(pipe(&terminal) == 0)
        defer { close(terminal[0]); close(terminal[1]) }
        try #require(pipe(&signals) == 0)
        defer { close(signals[0]); close(signals[1]) }
        try #require(pipe(&updates) == 0)
        defer { close(updates[0]); close(updates[1]) }
        var byte: UInt8 = 1
        #expect(write(updates[1], &byte, 1) == 1)
        #expect(tui_wait_readable_updates(terminal[0], signals[0], updates[0], 0) == 4)
        #expect(read(updates[0], &byte, 1) == 1)
        #expect(tui_wait_readable_updates(terminal[0], signals[0], updates[0], 0) == 0)
    }

    @Test func `invalid select descriptors and timeouts are rejected`() {
        #expect(tui_wait_readable(-1, 0, 0) == -1)
        #expect(errno == EINVAL)
        #expect(tui_wait_readable(0, Int32.max, 0) == -1)
        #expect(errno == EINVAL)
        #expect(tui_wait_writable(Int32.max, 0) == -1)
        #expect(errno == EINVAL)
        #expect(tui_wait_writable(0, -1) == -1)
        #expect(errno == EINVAL)
    }
}
