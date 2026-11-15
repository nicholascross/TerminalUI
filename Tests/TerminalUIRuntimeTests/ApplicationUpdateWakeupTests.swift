@testable import TerminalUIRuntime
import Testing
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

struct ApplicationUpdateWakeupTests {
    @Test func `updates are coalesced drained and closed`() throws {
        let wakeup = try ApplicationUpdateWakeup()
        var descriptor = pollfd(fd: wakeup.descriptor, events: Int16(POLLIN), revents: 0)
        #expect(poll(&descriptor, 1, 0) == 0)
        for _ in 0 ..< 1000 {
            wakeup.signal()
        }
        #expect(poll(&descriptor, 1, 0) == 1)
        wakeup.drain()
        #expect(poll(&descriptor, 1, 0) == 0)
        wakeup.signal()
        #expect(poll(&descriptor, 1, 0) == 1)
        wakeup.finish()
        wakeup.signal(); wakeup.drain(); wakeup.finish()
    }
}
