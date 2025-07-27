// InputParser: incremental state machine for parsing input bytes into InputEvent
import Foundation

public struct InputParser: Sendable {
    public init() {}

    /// Feed one byte. Returns an event if a complete token was recognized, else nil.
    public mutating func consume(_ byte: UInt8) -> InputEvent? {
        switch state {
        case .normal:
            return consumeNormal(byte)
        case .esc:
            return consumeEsc(byte)
        case .csi(let buf):
            return consumeCSI(byte, buf: buf)
        case .ss3:
            return consumeSS3(byte)
        }
    }

    private mutating func consumeNormal(_ byte: UInt8) -> InputEvent? {
        if utf8Need > 0 {
            return consumeUtf8Continuation(byte)
        }
        if byte == escapeCode {
            state = .esc
            return nil
        }
        if let event = controlEvent(for: byte) {
            return event
        }
        if let event = consumeUtf8LeadByte(byte) {
            return event
        }
        if utf8Need > 0 {
            return nil
        }
        if let event = consumePrintableAscii(byte) {
            return event
        }
        return .unknown
    }

    private mutating func consumeUtf8Continuation(_ byte: UInt8) -> InputEvent? {
        // valid continuation bytes are 10xxxxxx
        if byte & 0xC0 == 0x80 {
            utf8Buf.append(byte)
            if utf8Buf.count == utf8Need {
                let event: InputEvent
                if let scalar = String(bytes: utf8Buf, encoding: .utf8)?.first {
                    event = .char(scalar)
                } else {
                    event = .unknown
                }
                utf8Buf.removeAll()
                utf8Need = 0
                return event
            }
            return nil
        } else {
            utf8Buf.removeAll()
            utf8Need = 0
            return .unknown
        }
    }

    private func controlEvent(for byte: UInt8) -> InputEvent? {
        switch byte {
        case 3:
            return .ctrlC
        case 4:
            return .submit
        case carriageReturn, lineFeed:
            return .enter
        case deleteCode, backspaceCode:
            return .backspace
        case tabCode:
            return inPasteMode ? .char("\t") : .tab
        default:
            return nil
        }
    }

    private mutating func consumeUtf8LeadByte(_ byte: UInt8) -> InputEvent? {
        guard byte & 0x80 != 0 else { return nil }
        let need: Int
        if byte & 0xE0 == 0xC0 {
            need = 2
        } else if byte & 0xF0 == 0xE0 {
            need = 3
        } else if byte & 0xF8 == 0xF0 {
            need = 4
        } else {
            return .unknown
        }
        utf8Buf = [byte]
        utf8Need = need
        return nil
    }

    private func consumePrintableAscii(_ byte: UInt8) -> InputEvent? {
        guard byte >= 0x20 && byte <= 0x7E else { return nil }
        return .char(Character(UnicodeScalar(byte)))
    }

    private mutating func consumeEsc(_ byte: UInt8) -> InputEvent? {
        state = .normal
        switch byte {
        case UInt8(ascii: "["):
            state = .csi(buf: [])
            return nil
        case UInt8(ascii: "O"):
            state = .ss3
            return nil
        default:
            return .unknown
        }
    }

    private mutating func consumeCSI(_ byte: UInt8, buf: [UInt8]) -> InputEvent? {
        var buf = buf
        buf.append(byte)
        if buf.count > maxCSILength {
            state = .normal
            return .unknown
        }
        // final byte: paste or arrow
        if byte == UInt8(ascii: "~") {
            state = .normal
            let body = String(bytes: buf.dropLast(), encoding: .ascii) ?? ""
            if body == "200" {
                inPasteMode = true
                return .pasteStart
            }
            if body == "201" {
                inPasteMode = false
                return .pasteEnd
            }
            return .unknown
        }
        if let event = arrowMap[byte] {
            state = .normal
            return event
        }
        // continue accumulating intermediate/parameter bytes
        state = .csi(buf: buf)
        return nil
    }

    private mutating func consumeSS3(_ byte: UInt8) -> InputEvent? {
        state = .normal
        if let event = arrowMap[byte] {
            return event
        }
        return .unknown
    }

    /// Signal end-of-stream to flush partial state (if any). Returns a final event or nil.
    public mutating func flushEOF() -> InputEvent? {
        if case .esc = state {
            state = .normal
            return .unknown
        }
        if case .csi = state {
            state = .normal
            return .unknown
        }
        if case .ss3 = state {
            state = .normal
            return .unknown
        }
        if utf8Need > 0 {
            utf8Buf.removeAll()
            utf8Need = 0
            return .unknown
        }
        return nil
    }

    // MARK: - Internal state
    private var state: State = .normal
    private var inPasteMode = false
    private var utf8Buf: [UInt8] = []
    private var utf8Need: Int = 0
}

private enum State {
    case normal
    case esc
    case csi(buf: [UInt8])
    case ss3
}

// MARK: - Constants
private let escapeCode: UInt8 = 0x1B
private let carriageReturn: UInt8 = 13
private let lineFeed: UInt8 = 10
private let deleteCode: UInt8 = 127
private let backspaceCode: UInt8 = 8
private let tabCode: UInt8 = 9
private let maxCSILength = 32
private let arrowMap: [UInt8: InputEvent] = [
    UInt8(ascii: "A"): .upArrow,
    UInt8(ascii: "B"): .downArrow,
    UInt8(ascii: "C"): .rightArrow,
    UInt8(ascii: "D"): .leftArrow
]
