import Foundation
import TerminalUICore

/// Text layout shared by measurement and painting at one available width.
package struct WrappedText {
    package let lines: [String]
    package let width: Int

    package init(_ text: String, width available: Int) {
        let lines = Self.wrap(text, width: available)
        self.lines = lines
        width = lines.map { line in
            line.prefix(4096).reduce(0) { min(4096, $0 + max(1, CellWidth.width(of: $1))) }
        }.max() ?? 0
    }

    private static func wrap(_ text: String, width: Int) -> [String] {
        guard width > 0 else { return [] }
        var lines = [""]
        var length = 0
        for character in text.prefix(100000) {
            if character == "\n" || character == "\r" || character == "\r\n" {
                lines.append(""); length = 0; continue
            }
            let characters: [Character] = character == "\t" ? Array(repeating: " ", count: 4 - length % 4) : [character]
            for next in characters {
                let charWidth = max(1, CellWidth.width(of: next))
                if length > 0, length + charWidth > width {
                    if next == " " {
                        lines.append("")
                        length = 0
                        continue
                    }
                    if let space = lines[lines.count - 1].lastIndex(of: " ") {
                        let line = lines.removeLast()
                        let before = String(line[..<space]).trimmingCharacters(in: .whitespaces)
                        let after = String(line[line.index(after: space)...]).trimmingCharacters(in: .whitespaces)
                        lines.append(before)
                        lines.append(after)
                        length = after.prefix(4096).reduce(0) { min(4096, $0 + max(1, CellWidth.width(of: $1))) }
                    } else {
                        lines.append("")
                        length = 0
                    }
                    if next == " ", length == 0 { continue }
                }
                lines[lines.count - 1].append(next)
                length += charWidth
            }
        }
        return lines
    }
}
