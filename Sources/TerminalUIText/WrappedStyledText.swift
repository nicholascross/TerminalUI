import TerminalUICore

/// Wrapped runs refer back to spans so roles, overrides and themes stay draw-time inputs.
package struct WrappedStyledText {
    package struct Run {
        package let text: String
        package let spanIndex: Int
        package let column: Int
        package let sourceMap: TextSourceMap?
    }

    package struct Line {
        package let runs: [Run]
        package let width: Int
    }

    private struct Glyph {
        let character: Character
        let spanIndex: Int
        let sourceRange: Range<String.Index>?
        let sourceBytes: Range<Int>?
        let width: Int
    }

    package let lines: [Line]
    package let width: Int

    package init(_ texts: [String], width: Int?, tracksSource: Bool = false) {
        lines = Self.wrap(texts, width: width, tracksSource: tracksSource)
        self.width = lines.lazy.map(\.width).max() ?? 0
    }

    private static func wrap(_ texts: [String], width: Int?, tracksSource: Bool) -> [Line] {
        if let width, width <= 0 { return [] }
        var lines: [Line] = []
        var glyphs: [Glyph] = []
        var length = 0
        var processed = 0
        var sourceOffset = 0
        var previousWasCR = false

        spans: for (spanIndex, text) in texts.enumerated() {
            var index = text.startIndex
            while index < text.endIndex {
                guard processed < 100000 else { break spans }
                processed += 1
                let character = text[index]
                let nextIndex = text.index(after: index)
                defer { index = nextIndex }
                let sourceStart = sourceOffset
                if tracksSource { sourceOffset += character.utf8.count }

                if width == nil {
                    let continuesCRLF = previousWasCR && character == "\n"
                    previousWasCR = character == "\r"
                    if continuesCRLF { continue }
                }
                if character == "\n" || character == "\r" || character == "\r\n" || (width == nil && character.isNewline) {
                    lines.append(makeLine(glyphs[...], texts: texts))
                    glyphs.removeAll(keepingCapacity: true)
                    length = 0
                    continue
                }

                let isTab = character == "\t"
                let glyph = Glyph(
                    character: isTab ? " " : character,
                    spanIndex: spanIndex,
                    sourceRange: isTab ? nil : index ..< nextIndex,
                    sourceBytes: tracksSource ? sourceStart ..< sourceOffset : nil,
                    width: isTab ? 1 : max(1, CellWidth.width(of: character)),
                )
                let count = isTab ? 4 - length % 4 : 1
                for _ in 0 ..< count {
                    if let width, length > 0, length + glyph.width > width {
                        if glyph.character == " " {
                            lines.append(makeLine(glyphs[...], texts: texts))
                            glyphs.removeAll(keepingCapacity: true)
                            length = 0
                            continue
                        }
                        if let space = glyphs.lastIndex(where: { $0.character == " " }) {
                            lines.append(makeLine(trimmed(glyphs[..<space]), texts: texts))
                            glyphs = Array(trimmed(glyphs[(space + 1)...]))
                            length = glyphs.reduce(0) { $0 + $1.width }
                        } else {
                            lines.append(makeLine(glyphs[...], texts: texts))
                            glyphs.removeAll(keepingCapacity: true)
                            length = 0
                        }
                    }
                    glyphs.append(glyph)
                    length += glyph.width
                }
            }
        }
        lines.append(makeLine(glyphs[...], texts: texts))
        return lines
    }

    private static func trimmed(_ glyphs: ArraySlice<Glyph>) -> ArraySlice<Glyph> {
        let leadingTrimmed = glyphs.drop { $0.character.isWhitespace }
        let end = leadingTrimmed.lastIndex { !$0.character.isWhitespace }.map { $0 + 1 } ?? leadingTrimmed.endIndex
        return leadingTrimmed[..<end]
    }

    private static func makeLine(_ glyphs: ArraySlice<Glyph>, texts: [String]) -> Line {
        var runs: [Run] = []
        var column = 0
        var start = glyphs.startIndex
        while start < glyphs.endIndex {
            let first = glyphs[start]
            let startColumn = column
            var end = start
            var sourceEnd: String.Index?
            repeat {
                let glyph = glyphs[end]
                sourceEnd = glyph.sourceRange?.upperBound
                column += glyph.width
                end += 1
                // Canvas replaces unsafe wide characters with one cell. Preserve the following column.
                if glyph.width == 2, !CellWidth.isSafe(glyph.character) { break }
            } while end < glyphs.endIndex && glyphs[end].spanIndex == first.spanIndex
                && glyphs[end].sourceRange?.lowerBound == sourceEnd

            let text: String
            if let sourceStart = first.sourceRange?.lowerBound, let sourceEnd {
                // Keep original grapheme boundaries, including around tabs and trimmed whitespace.
                text = String(texts[first.spanIndex][sourceStart ..< sourceEnd])
            } else {
                text = String(repeating: " ", count: end - start)
            }
            let map = first.sourceBytes.map { sourceMap(glyphs[start ..< end], start: $0, text: text) }
            runs.append(Run(text: text, spanIndex: first.spanIndex, column: startColumn, sourceMap: map))
            start = end
        }
        return Line(runs: runs, width: column)
    }

    private static func sourceMap(_ glyphs: ArraySlice<Glyph>, start: Range<Int>, text: String) -> TextSourceMap {
        var result = TextSourceMap()
        if glyphs.first?.sourceRange != nil, let end = glyphs.last?.sourceBytes?.upperBound {
            result.append(byteCount: text.utf8.count, source: start.lowerBound ..< end)
        } else {
            for glyph in glyphs {
                if let source = glyph.sourceBytes { result.append(byteCount: 1, source: source) }
            }
        }
        return result
    }
}
