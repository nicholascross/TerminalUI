import Foundation
import TerminalUICore

/// Incrementally decodes terminal keyboard, paste and SGR mouse sequences.
/// Call `flushEscape()` after the configured escape-key timeout.
public struct InputDecoder {
    private var buffer: [UInt8] = []
    private var paste: [UInt8]?
    private var discardingControlString = false
    private var controlStringEscape = false
    private var discardingSequence = false
    /// Whether the most recently completed or active paste exceeded the configured limit.
    public private(set) var pasteWasTruncated = false
    /// Number of truncated pastes completed by the most recent call to `feed`.
    public private(set) var completedTruncatedPastes = 0
    private let pasteLimit: Int
    private let pasteEnd = Array("\u{1B}[201~".utf8)

    public init(pasteLimit: Int = 1_048_576) {
        self.pasteLimit = max(0, pasteLimit)
    }

    /// Compatibility keyboard stream. Mouse packets are consumed and omitted.
    public mutating func feed(_ bytes: some Sequence<UInt8>) -> [KeyEvent] {
        feedEvents(bytes).compactMap { if case let .key(key) = $0 { key } else { nil } }
    }

    /// Decodes keyboard and mouse reports in their original order.
    public mutating func feedEvents(_ bytes: some Sequence<UInt8>) -> [TerminalEvent] {
        completedTruncatedPastes = 0
        buffer.append(contentsOf: bytes)
        var events: [TerminalEvent] = []
        func appendKey(_ key: KeyEvent) { events.append(.key(key)) }
        while !buffer.isEmpty {
            if discardingSequence {
                let byte = buffer.removeFirst()
                if (0x40...0x7e).contains(byte) { discardingSequence = false }
                continue
            }
            if discardingControlString {
                let byte = buffer.removeFirst()
                if byte == 7 || (controlStringEscape && byte == 92) {
                    discardingControlString = false
                    controlStringEscape = false
                } else {
                    controlStringEscape = byte == 27
                }
                continue
            }
            if paste != nil {
                if let end = buffer.windowsIndex(of: pasteEnd) {
                    appendPaste(buffer.prefix(end))
                    buffer.removeFirst(end + pasteEnd.count)
                    appendKey(.paste(String(decoding: paste ?? [], as: UTF8.self)))
                    if pasteWasTruncated { completedTruncatedPastes += 1 }
                    paste = nil
                } else {
                    let count = max(0, buffer.count - pasteEnd.count + 1)
                    appendPaste(buffer.prefix(count))
                    buffer.removeFirst(count)
                    break
                }
                continue
            }
            if buffer[0] == 27 {
                let sequences = Self.keySequences
                let start = Array("\u{1B}[200~".utf8)
                if buffer.count >= 2, [93, 80, 88, 94, 95].contains(buffer[1]) {
                    buffer.removeFirst(2)
                    discardingControlString = true
                    controlStringEscape = false
                } else if buffer.starts(with: start) {
                    buffer.removeFirst(start.count)
                    paste = []
                    pasteWasTruncated = false
                } else if buffer.starts(with: [27, 91, 77]) {
                    // Legacy mouse reports carry three payload bytes after CSI M.
                    // Discard the whole report, including payload that resembles keys.
                    guard buffer.count >= 6 else { break }
                    buffer.removeFirst(6)
                } else if buffer.starts(with: [27, 91, 60]),
                          let end = buffer.dropFirst(3).firstIndex(where: { (0x40...0x7e).contains($0) }) {
                    if end < 128, let mouse = Self.mouseEvent(buffer[3..<end], final: buffer[end]) {
                        events.append(.mouse(mouse))
                    }
                    buffer.removeFirst(end + 1)
                } else if let match = sequences.first(where: { buffer.starts(with: $0.0) }) {
                    buffer.removeFirst(match.0.count)
                    appendKey(match.1)
                } else if let end = buffer.dropFirst(2).firstIndex(of: 117), buffer.starts(with: [27, 91]),
                          let key = modifiedKey(buffer[2..<end]) {
                    buffer.removeFirst(end + 1)
                    appendKey(key)
                } else if buffer.starts(with: [27, 91]),
                          let end = buffer.dropFirst(2).firstIndex(of: 126),
                          let key = otherModifiedKey(buffer[2..<end]) {
                    buffer.removeFirst(end + 1)
                    appendKey(key)
                } else if buffer.starts(with: [27, 91]),
                          let end = buffer.dropFirst(2).firstIndex(where: { (0x40...0x7e).contains($0) }),
                          let key = navigationKey(buffer[2...end]) {
                    buffer.removeFirst(end + 1)
                    appendKey(key)
                } else if (sequences.map(\.0) + [start]).contains(where: { $0.starts(with: buffer) }) {
                    break
                } else if buffer.count >= 2, buffer[1] == 91 || buffer[1] == 79 {
                    // Discard an unknown control sequence as a unit, never as a key press.
                    guard let end = buffer.dropFirst(2).firstIndex(where: { (0x40...0x7e).contains($0) }) else {
                        if buffer.count > 128 {
                            buffer.removeAll()
                            discardingSequence = true
                        }
                        break
                    }
                    buffer.removeFirst(end + 1)
                } else {
                    buffer.removeFirst()
                    if let byte = buffer.first, (32...126).contains(byte) {
                        buffer.removeFirst()
                        appendKey(.altCharacter(Character(UnicodeScalar(byte))))
                    } else {
                        appendKey(.escape)
                    }
                }
                continue
            }
            let byte = buffer[0]
            if byte < 32 || byte == 127 {
                buffer.removeFirst()
                switch byte {
                case 3: appendKey(.controlC)
                case 4: appendKey(.controlD)
                case 16: appendKey(.controlP)
                case 9: appendKey(.tab)
                case 10, 13: appendKey(.enter)
                case 8, 127: appendKey(.backspace)
                default: break
                }
                continue
            }
            let count: Int
            switch byte {
            case 0...0x7f: count = 1
            case 0xc2...0xdf: count = 2
            case 0xe0...0xef: count = 3
            case 0xf0...0xf4: count = 4
            default:
                buffer.removeFirst()
                continue
            }
            let available = min(count, buffer.count)
            if buffer[1..<available].contains(where: { !($0 >= 0x80 && $0 <= 0xbf) }) {
                buffer.removeFirst()
                continue
            }
            guard buffer.count >= count else { break }
            let data = Array(buffer.prefix(count))
            buffer.removeFirst(count)
            if let value = String(bytes: data, encoding: .utf8), let character = value.first {
                appendKey(.character(character))
            }
        }
        return events
    }

    /// Resolves a pending standalone Escape; incomplete control sequences are discarded.
    public mutating func flushEscape() -> [KeyEvent] {
        guard paste == nil, buffer.first == 27 else { return [] }
        let standalone = buffer.count == 1
        buffer.removeAll()
        return standalone ? [.escape] : []
    }

    private mutating func appendPaste(_ bytes: ArraySlice<UInt8>) {
        guard let existing = paste else { return }
        let available = max(0, pasteLimit - existing.count)
        if bytes.count > available { pasteWasTruncated = true }
        paste?.append(contentsOf: bytes.prefix(available))
    }

    // Lock-key flags may accompany otherwise unmodified or shifted cursor keys.
    private func navigationKey(_ sequence: ArraySlice<UInt8>) -> KeyEvent? {
        guard let final = sequence.last else { return nil }
        let parts = String(decoding: sequence.dropLast(), as: UTF8.self).split(separator: ";")
        guard parts.count == 2, parts[0] == "1", let modifiers = Int(parts[1]), modifiers > 0 else { return nil }
        let effective = (modifiers - 1) & ~192
        switch (final, effective) {
        case (65, 0): return .up
        case (66, 0): return .down
        case (67, 0): return .right
        case (68, 0): return .left
        case (65, 1): return .shiftUp
        case (66, 1): return .shiftDown
        case (67, 1): return .shiftRight
        case (68, 1): return .shiftLeft
        default: return nil
        }
    }

    private func modifiedKey(_ parameters: ArraySlice<UInt8>) -> KeyEvent? {
        guard let text = String(bytes: parameters, encoding: .utf8) else { return nil }
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count == 2, let code = Int(parts[0]), let modifiers = Int(parts[1]),
              modifiers > 0 else { return nil }
        return modifiedKey(code: code, modifiers: modifiers)
    }

    private func otherModifiedKey(_ parameters: ArraySlice<UInt8>) -> KeyEvent? {
        guard let text = String(bytes: parameters, encoding: .utf8) else { return nil }
        let parts = text.split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "27", let modifiers = Int(parts[1]), let code = Int(parts[2]),
              modifiers > 0 else { return nil }
        return modifiedKey(code: code, modifiers: modifiers)
    }

    private func modifiedKey(code: Int, modifiers: Int) -> KeyEvent? {
        let effective = (modifiers - 1) & ~192
        if code == 9 {
            switch effective {
            case 0: return .tab
            case 1: return .backTab
            default: return nil
            }
        }
        guard (32...126).contains(code), let scalar = UnicodeScalar(code) else { return nil }
        switch effective {
        case 2: return .altCharacter(Character(scalar))
        case 4: break
        default: return nil
        }
        switch code {
        case 99: return .controlC
        case 100: return .controlD
        case 112: return .controlP
        default: return .controlCharacter(Character(scalar))
        }
    }
}

private extension Array where Element == UInt8 {
    func windowsIndex(of needle: [UInt8]) -> Int? {
        guard count >= needle.count else { return nil }
        return (0...(count - needle.count)).first { self[$0..<$0 + needle.count].elementsEqual(needle) }
    }
}
