import TerminalUICore

extension InputDecoder {
    static func mouseEvent(_ parameters: ArraySlice<UInt8>, final: UInt8) -> MouseEvent? {
        guard final == 77 || final == 109 else { return nil }
        let parts = String(decoding: parameters, as: UTF8.self).split(separator: ";", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48 ... 57).contains($0) } }),
              let code = Int(parts[0]), let column = Int(parts[1]), let row = Int(parts[2]),
              column > 0, row > 0 else { return nil }
        let base = code & ~28
        let kind: MouseEvent.Kind
        let button: MouseEvent.Button
        switch base {
        case 0 ... 2:
            kind = final == 77 ? .press : .release
            button = base == 0 ? .primary : (base == 1 ? .middle : .secondary)
        case 32 ... 34:
            guard final == 77 else { return nil }
            kind = .drag
            button = base == 32 ? .primary : (base == 33 ? .middle : .secondary)
        case 64, 65:
            guard final == 77 else { return nil }
            kind = base == 64 ? .scrollUp : .scrollDown
            button = .primary
        default: return nil
        }
        return MouseEvent(kind, column: column - 1, row: row - 1, button: button,
                          shift: code & 4 != 0, alt: code & 8 != 0, control: code & 16 != 0)
    }
}
