/// A conservative display-column policy for common modern terminal emulators.
/// Ambiguous-width characters use one cell. Actual emoji widths vary by terminal.
public enum CellWidth {
    public static func width(of character: Character) -> Int {
        if character.asciiValue != nil { return 1 }
        let scalars = character.unicodeScalars
        guard let first = scalars.first else { return 0 }
        if scalars.allSatisfy({ scalar in
            switch scalar.properties.generalCategory {
            case .nonspacingMark, .enclosingMark, .format: return true
            default: return false
            }
        }) { return 0 }
        if scalars.contains(where: { $0.value == 0xfe0f || $0.value == 0x20e3 }) { return 2 }
        if scalars.contains(where: { $0.properties.isEmojiPresentation }) { return 2 }
        let value = first.value
        if (0x1100...0x115f).contains(value) || (0x2329...0x232a).contains(value)
            || (0x2e80...0xa4cf).contains(value) || (0xac00...0xd7a3).contains(value)
            || (0xf900...0xfaff).contains(value) || (0xfe10...0xfe19).contains(value)
            || (0xfe30...0xfe6f).contains(value) || (0xff00...0xff60).contains(value)
            || (0xffe0...0xffe6).contains(value) || (0x20000...0x3fffd).contains(value) {
            return 2
        }
        return 1
    }

    public static func isSafe(_ character: Character) -> Bool {
        if let ascii = character.asciiValue { return ascii >= 32 && ascii != 127 }
        return character.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            return value >= 32 && !(0x7f...0x9f).contains(value)
                && !(0x202a...0x202e).contains(value) && !(0x2066...0x2069).contains(value)
                && value != 0x061c && value != 0x200e && value != 0x200f
                && value != 0x2028 && value != 0x2029
        }
    }
}
