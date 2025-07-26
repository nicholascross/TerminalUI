import Foundation
import Darwin

public enum InputEvent {
    case char(Character)
    case enter, backspace, tab
    case submit           // e.g. ^D in raw mode
    case upArrow, downArrow, leftArrow, rightArrow
    case ctrlC
    case eof              // real end-of-file
    /// Bracketed-paste start/end markers
    case pasteStart, pasteEnd
    case unknown
}

public final class Input {
    private var inPasteMode = false

    public init() {}

    public func readEvent() throws -> InputEvent {
        while true {
            var byte: UInt8 = 0
            let n = read(STDIN_FILENO, &byte, 1)

            if n == 1 {
                // Normalize CR to LF inside paste
                if inPasteMode && byte == 13 { byte = 10 }

                if byte == 0x1B {               // ESC
                    if let ev = try parseEscape() { return ev }
                    continue                     // ignore + keep reading
                }

                switch byte {
                case 3:   return .ctrlC          // ^C (only delivered if ISIG is off)
                case 4:   return .submit         // ^D (raw mode)
                case 13, 10: return .enter
                case 127, 8: return .backspace
                case 9:
                    // In paste mode, treat literal tabs as input characters, not focus change
                    if inPasteMode { return .char(Character("\t")) }
                    return .tab

                case let b where b & 0x80 != 0:  // UTF-8 lead byte
                    let width: Int =
                        (b & 0xE0 == 0xC0) ? 2 :
                        (b & 0xF0 == 0xE0) ? 3 :
                        (b & 0xF8 == 0xF0) ? 4 : 1
                    var buf = [b]
                    for _ in 1..<width {
                        var nb: UInt8 = 0
                        guard read(STDIN_FILENO, &nb, 1) == 1 else { break }
                        // validate continuation byte
                        if nb & 0xC0 != 0x80 { buf = [b]; break }
                        buf.append(nb)
                    }
                    if let s = String(bytes: buf, encoding: .utf8), let ch = s.first {
                        return .char(ch)
                    }
                    return .unknown

                case 32...126:
                    return .char(Character(UnicodeScalar(byte)))

                default:
                    return .unknown
                }

            } else if n == 0 {
                return .eof                       // true EOF (pipe closed or ^D in cooked mode)
            } else {
                if errno == EINTR { continue }
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        }
    }

    // Read a single byte, retrying on EINTR and treating other errors or EOF as nil
    private func read1() -> UInt8? {
        var b: UInt8 = 0
        while true {
            let n = read(STDIN_FILENO, &b, 1)
            if n == 1 { return b }
            if n == 0 { return nil }
            if errno == EINTR { continue }
            return nil
        }
    }

    private func parseEscape() throws -> InputEvent? {
        guard let c = read1() else { return nil }


        if c == UInt8(ascii: "[") {
            // CSI: read until final byte 0x40..0x7E
            var seq: [UInt8] = []
            while true {
                guard let b = read1() else { return nil }
                seq.append(b)
                if b >= 0x40 && b <= 0x7E { break }
            }

            if seq.last == UInt8(ascii: "~") {
                // Bracketed paste markers: 200~ start, 201~ end
                let body = String(decoding: seq.dropLast(), as: Unicode.ASCII.self)
                if body == "200" {
                    inPasteMode = true
                    return .pasteStart
                }
                if body == "201" {
                    inPasteMode = false
                    return .pasteEnd
                }
            }

            // Arrow keys, allow params like "1;5A"
            if let last = seq.last {
                switch last {
                case UInt8(ascii: "A"): return .upArrow
                case UInt8(ascii: "B"): return .downArrow
                case UInt8(ascii: "C"): return .rightArrow
                case UInt8(ascii: "D"): return .leftArrow
                default: break
                }
            }
            return nil

        } else if c == UInt8(ascii: "O") {
            // SS3/application mode arrows: ESC O A/B/C/D
            guard let b = read1() else { return nil }
            switch b {
            case UInt8(ascii: "A"): return .upArrow
            case UInt8(ascii: "B"): return .downArrow
            case UInt8(ascii: "C"): return .rightArrow
            case UInt8(ascii: "D"): return .leftArrow
            default: return nil
            }
        } else {
            // Likely Meta/Alt prefix (ESC + char). Let the next byte be read normally.
            return nil
        }
    }
}
