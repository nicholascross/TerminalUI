import Darwin
import Foundation

private let ESC: UInt8 = 0x1B
private let CR: UInt8 = 13
private let LF: UInt8 = 10
private let DEL: UInt8 = 127
private let BS: UInt8 = 8
private let TAB: UInt8 = 9

/// A discrete key or control event read from the terminal.
public enum InputEvent {
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
    private var inPasteMode = false

    public init() {}

    /// Read the next input event from stdin.
    ///
    /// - returns: A discrete `InputEvent`.
    /// - throws: A POSIX error on read failure.
    public func readEvent() throws -> InputEvent {
        while true {
            guard let raw = try readByte() else {
                return .eof
            }
            var byte = raw

            // Normalize CR to LF inside paste
            if inPasteMode && byte == CR {
                byte = LF
            }

            // ESC initiates an escape sequence
            if byte == ESC {
                if let ev = try parseEscape() {
                    return ev
                }
                continue
            }

            switch byte {
            case 3:
                return .ctrlC
            case 4:
                return .submit
            case CR, LF:
                return .enter
            case DEL, BS:
                return .backspace
            case TAB:
                if inPasteMode {
                    return .char("\t")
                }
                return .tab
            case let byte where byte & 0x80 != 0:
                if let character = try decodeUTF8Character(lead: byte) {
                    return .char(character)
                }
                return .unknown
            case 32 ... 126:
                return .char(Character(UnicodeScalar(byte)))
            default:
                return .unknown
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

    /// Decode a UTF-8 character from the initial lead byte, reading additional bytes as needed.
    private func decodeUTF8Character(lead b: UInt8) throws -> Character? {
        let width: Int =
            (b & 0xE0 == 0xC0) ? 2 :
            (b & 0xF0 == 0xE0) ? 3 :
            (b & 0xF8 == 0xF0) ? 4 : 1
        var buf = [b]
        for _ in 1 ..< width {
            guard let nb = try readByte(), (nb & 0xC0) == 0x80 else {
                return nil
            }
            buf.append(nb)
        }
        return String(bytes: buf, encoding: .utf8)?.first
    }

    private let arrowMap: [UInt8: InputEvent] = [
        UInt8(ascii: "A"): .upArrow,
        UInt8(ascii: "B"): .downArrow,
        UInt8(ascii: "C"): .rightArrow,
        UInt8(ascii: "D"): .leftArrow,
    ]

    /// Parse an ESC‑initiated sequence (CSI or SS3).
    private func parseEscape() throws -> InputEvent? {
        guard let character = try readByte() else {
            return nil
        }

        if character == UInt8(ascii: "[") {
            // CSI: read until final byte 0x40..0x7E
            var seq: [UInt8] = []
            while true {
                guard let b = try readByte() else {
                    return nil
                }
                seq.append(b)
                if b >= 0x40 && b <= 0x7E {
                    break
                }
            }

            // Bracketed-paste: 200~ start, 201~ end
            if let ev = parseCSISequence(seq) {
                return ev
            }
            return nil

        } else if character == UInt8(ascii: "O") {
            // SS3/application-mode arrows
            guard let b = try readByte() else {
                return nil
            }
            return arrowMap[b]
        }
        // Not a CSI or SS3, likely Meta/Alt prefix: ignore ESC and treat next normally
        return nil
    }

    /// Handle CSI sequence for arrow keys and bracketed paste markers.
    private func parseCSISequence(_ seq: [UInt8]) -> InputEvent? {
        if seq.last == UInt8(ascii: "~") {
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
        guard let last = seq.last else {
            return nil
        }
        return arrowMap[last]
    }
}
