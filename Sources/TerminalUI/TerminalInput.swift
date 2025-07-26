import Darwin
import Foundation


/// A discrete key or control event read from the terminal.
public enum InputEvent: Equatable, Hashable, Sendable {
    /// A Unicode character that was typed.
    case char(Character)
    /// The Enter, Backspace/Delete, or Tab keys.
    case enter, backspace, tab
    /// A “submit” control (e.g. ^D in raw mode).
    case submit
    /// Arrow keys.
    case upArrow, downArrow, leftArrow, rightArrow
    /// ^C (only delivered if ISIG is off).
    case ctrlC
    /// End‐of‐file (pipe closed or ^D in cooked mode).
    case eof
    /// Bracketed‐paste start/end markers.
    case pasteStart, pasteEnd
    /// Unrecognized or invalid sequence.
    case unknown
}

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
                if let ev = parser.flushEOF() {
                    return ev
                }
                return .eof
            }
            if let ev = parser.consume(raw) {
                return ev
            }
        }
    }

    /// Read one byte from stdin. Returns `nil` on EOF, or throws on error.
    private func readByte() throws -> UInt8? {
        var byte: UInt8 = 0
        while true {
            let n = read(STDIN_FILENO, &byte, 1)
            if n == 1 {
                return byte
            }
            if n == 0 {
                return nil
            }
            if errno == EINTR {
                continue
            }
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }

}
