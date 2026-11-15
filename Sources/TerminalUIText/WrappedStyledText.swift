import TerminalUICore

/// Wrapped glyphs refer back to spans so roles, overrides and themes stay draw-time inputs.
package struct WrappedStyledText {
    package struct Glyph {
        package let character: Character
        package let spanIndex: Int
    }

    package let lines: [[Glyph]]
    package let width: Int

    package init(_ texts: [String], width: Int) {
        lines = Self.wrap(texts, width: width)
        self.width = lines.map { line in
            line.reduce(0) { $0 + max(1, CellWidth.width(of: $1.character)) }
        }.max() ?? 0
    }

    private static func wrap(_ texts: [String], width: Int) -> [[Glyph]] {
        guard width > 0 else { return [] }
        var lines: [[Glyph]] = [[]]
        var length = 0
        var processed = 0
        for (spanIndex, text) in texts.enumerated() {
            for character in text {
                guard processed < 100000 else { return lines }
                processed += 1
                if character == "\n" || character == "\r" || character == "\r\n" {
                    lines.append([]); length = 0; continue
                }
                let characters: [Character] = character == "\t" ? Array(repeating: " ", count: 4 - length % 4) : [character]
                for next in characters {
                    let charWidth = max(1, CellWidth.width(of: next))
                    if length > 0, length + charWidth > width {
                        if next == " " { lines.append([]); length = 0; continue }
                        if let space = lines[lines.count - 1].lastIndex(where: { $0.character == " " }) {
                            let old = lines.removeLast()
                            let before = Array(old[..<space]).drop { $0.character.isWhitespace }
                            let after = Array(old[(space + 1)...]).drop { $0.character.isWhitespace }
                            lines.append(Array(before.reversed().drop { $0.character.isWhitespace }.reversed()))
                            lines.append(Array(after.reversed().drop { $0.character.isWhitespace }.reversed()))
                            length = lines[lines.count - 1].reduce(0) { $0 + max(1, CellWidth.width(of: $1.character)) }
                        } else { lines.append([]); length = 0 }
                    }
                    lines[lines.count - 1].append(Glyph(character: next, spanIndex: spanIndex))
                    length += charWidth
                }
            }
        }
        return lines
    }
}
