import Foundation
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// A separate, coalesced update channel. The reader is joined before this object is closed.
final class ApplicationUpdateWakeup: @unchecked Sendable {
    let descriptor: Int32
    private let writer: Int32
    private let lock = NSLock()
    private var pending = false
    private var closed = false

    init() throws {
        var descriptors: [Int32] = [-1, -1]
        guard pipe(&descriptors) == 0 else { throw TerminalError.systemCall("update pipe", errno) }
        descriptor = descriptors[0]; writer = descriptors[1]
        for fd in descriptors {
            guard fcntl(fd, F_SETFL, O_NONBLOCK) >= 0, fcntl(fd, F_SETFD, FD_CLOEXEC) >= 0 else {
                let code = errno
                close(descriptors[0]); close(descriptors[1])
                throw TerminalError.systemCall("update pipe flags", code)
            }
        }
    }

    func signal() {
        lock.lock(); defer { lock.unlock() }
        guard !closed, !pending else { return }
        var byte: UInt8 = 1
        var count: Int
        repeat {
            count = write(writer, &byte, 1)
        } while count < 0 && errno == EINTR
        if count == 1 || (count < 0 && errno == EAGAIN) {
            pending = true
        }
    }

    func drain() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        var buffer = [UInt8](repeating: 0, count: 64)
        while true {
            let count = read(descriptor, &buffer, buffer.count)
            if count > 0 || (count < 0 && errno == EINTR) { continue }
            break
        }
        pending = false
    }

    func finish() {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        closed = true
        close(descriptor); close(writer)
    }

    deinit { finish() }
}
