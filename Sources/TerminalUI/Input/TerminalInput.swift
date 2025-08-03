import Darwin
import Foundation

/// Reads raw input bytes from stdin and turns them into higher‑level `InputEvent`s.
public final class TerminalInput {
    private var parser = InputParser()

    public init() {}

    /// Read the next input event from stdin.
    ///
    /// - returns: A discrete `InputEvent`.
    /// - throws: A POSIX error on read failure.
    public func readEvent() throws -> InputEvent {
        while true {
            guard let raw = try readByte() else {
                if let parsedEvent = parser.flushEOF() {
                    return parsedEvent
                }
                return .eof
            }
            if let parsedEvent = parser.consume(raw) {
                return parsedEvent
            }
        }
    }

    /// Read one byte from stdin. Returns `nil` on EOF, or throws on error.
    private func readByte() throws -> UInt8? {
        var byte: UInt8 = 0
        while true {
            let bytesRead = read(STDIN_FILENO, &byte, 1)
            if bytesRead == 1 {
                return byte
            }
            if bytesRead == 0 {
                return nil
            }
            if errno == EINTR {
                continue
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

    /// Async sequence of discrete `InputEvent`s from stdin, ending on EOF or error.
    public func events() -> AsyncThrowingStream<InputEvent, Error> {
        AsyncThrowingStream { continuation in
            Task.detached {
                do {
                    while true {
                        let event = try self.readEvent()
                        continuation.yield(event)
                        if event == .eof { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

}

// MARK: - InputEventSource conformance

extension TerminalInput: InputEventSource {}
