#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// Serializes one frame through a potentially short-writing, nonblocking transport.
struct TerminalOutputWriter {
    func writeAll(
        _ bytes: [UInt8],
        write: (UnsafeRawBufferPointer) -> Int,
        error: () -> Int32,
        waitWritable: () throws -> Bool,
    ) throws {
        try bytes.withUnsafeBytes { buffer in
            var position = 0
            var stalls = 0
            while position < buffer.count {
                let remaining = UnsafeRawBufferPointer(rebasing: buffer[position...])
                let count = write(remaining)
                if count > 0 {
                    guard count <= remaining.count else { throw TerminalError.outputUnavailable }
                    position += count
                    stalls = 0
                    continue
                }
                let failure = count == 0 ? EIO : error()
                if failure == EINTR { continue }
                if failure == EAGAIN || failure == EWOULDBLOCK {
                    stalls += 1
                    let writable = try waitWritable()
                    guard stalls < 20, writable else { throw TerminalError.outputUnavailable }
                    continue
                }
                throw TerminalError.systemCall("write", failure)
            }
        }
    }
}
