import Foundation
import TerminalUICore

/// Text layout shared by measurement and painting at one available width.
package struct WrappedText {
    package let lines: [String]
    package let sourceMaps: [TextSourceMap]?
    package let width: Int

    package init(_ text: String, width available: Int?, tracksSource: Bool = false) {
        let (lines, sourceMaps) = Self.wrap(text, width: available, tracksSource: tracksSource)
        self.lines = lines
        self.sourceMaps = sourceMaps
        width = lines.map { line in
            line.prefix(4096).reduce(0) { min(4096, $0 + max(1, CellWidth.width(of: $1))) }
        }.max() ?? 0
    }

    private static func wrap(_ text: String, width: Int?, tracksSource: Bool) -> ([String], [TextSourceMap]?) {
        if let width, width <= 0 { return ([], nil) }
        var lines: [String] = []
        var maps: [TextSourceMap]? = tracksSource ? [] : nil
        var line = ""
        var map: TextSourceMap? = tracksSource ? TextSourceMap() : nil
        var sourceOffset = 0
        var length = 0

        func finishLine() {
            lines.append(line)
            if let map { maps?.append(map) }
            line = ""
            map = tracksSource ? TextSourceMap() : nil
            length = 0
        }

        for character in text.prefix(100000) {
            let start = sourceOffset
            if tracksSource { sourceOffset += character.utf8.count }
            if character == "\n" || character == "\r" || character == "\r\n" || (width == nil && character.isNewline) {
                finishLine()
                continue
            }
            let characters: [Character] = character == "\t" ? Array(repeating: " ", count: 4 - length % 4) : [character]
            for next in characters {
                let charWidth = max(1, CellWidth.width(of: next))
                if let width, length > 0, length + charWidth > width {
                    if next == " " {
                        finishLine()
                        continue
                    }
                    if let space = line.lastIndex(of: " ") {
                        let before = line[..<space]
                        let after = line[line.index(after: space)...]
                        let left = before.trimmingCharacters(in: .whitespaces)
                        let right = after.trimmingCharacters(in: .whitespaces)
                        let rightMap = map.map { trimmedMap($0, for: after, trimmed: right, in: line) }
                        map = map.map { trimmedMap($0, for: before, trimmed: left, in: line) }
                        line = left
                        finishLine()
                        line = right
                        map = rightMap
                        length = right.prefix(4096).reduce(0) { min(4096, $0 + max(1, CellWidth.width(of: $1))) }
                    } else {
                        finishLine()
                    }
                    if next == " ", length == 0 { continue }
                }
                line.append(next)
                map?.append(byteCount: next.utf8.count, source: start ..< sourceOffset)
                length += charWidth
            }
        }
        finishLine()
        return (lines, maps)
    }

    private static func trimmedMap(_ map: TextSourceMap, for part: Substring, trimmed: String, in line: String) -> TextSourceMap {
        guard let first = part.unicodeScalars.firstIndex(where: { !CharacterSet.whitespaces.contains($0) }) else {
            return TextSourceMap()
        }
        let offset = line.utf8.distance(from: line.startIndex, to: first)
        return map.slice(offset ..< (offset + trimmed.utf8.count))
    }
}
