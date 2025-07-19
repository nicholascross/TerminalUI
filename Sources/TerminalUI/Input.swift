import Foundation
import Darwin.C

/// Represents a decoded key or control event.
public enum InputEvent {
    case char(Character)
    case enter
    case backspace
    case tab
    case upArrow
    case downArrow
    case leftArrow
    case rightArrow
    case ctrlC
    case unknown
}

/// Reads and decodes input events from stdin in raw mode.
public class Input {
    public init() {}

    /// Read the next input event.
    public func readEvent() throws -> InputEvent {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        guard n == 1 else { return .unknown }
        if byte == 0x1B {
            // Escape sequence: read two more bytes
            var seq = [UInt8](repeating: 0, count: 2)
            let n = read(STDIN_FILENO, &seq, 2)
            if n == 2 && seq[0] == UInt8(ascii: "[") {
                switch seq[1] {
                case UInt8(ascii: "A"): return .upArrow
                case UInt8(ascii: "B"): return .downArrow
                case UInt8(ascii: "C"): return .rightArrow
                case UInt8(ascii: "D"): return .leftArrow
                default: break
                }
            }
            return .unknown
        }
        switch byte {
        case 3:
            return .ctrlC
        case 13, 10:
            return .enter
        case 127, 8:
            return .backspace
        case 9:
            return .tab
        case let b where b >= 32 && b <= 126:
            return .char(Character(UnicodeScalar(b)))
        default:
            return .unknown
        }
    }
}
