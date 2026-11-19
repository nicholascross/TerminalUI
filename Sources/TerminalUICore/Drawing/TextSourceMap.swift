/// Relates UTF-8 ranges in a drawn string to their original text.
package struct TextSourceMap {
    package struct Span {
        package let drawn: Range<Int>
        let source: Range<Int>

        /// Tabs can occupy several drawn bytes that all refer to the same source byte.
        package func sourceRange(for bytes: Range<Int>) -> Range<Int> {
            guard drawn.count == source.count else { return source }
            let clipped = drawn.clamped(to: bytes)
            let start = source.lowerBound + clipped.lowerBound - drawn.lowerBound
            return start ..< (start + clipped.count)
        }
    }

    package private(set) var spans: [Span] = []

    package init() {}

    package mutating func append(byteCount: Int, source: Range<Int>) {
        guard byteCount > 0 else { return }
        let last = spans.last
        let start = last?.drawn.upperBound ?? 0
        let end = start + byteCount
        if let last {
            if last.source == source {
                spans[spans.count - 1] = Span(drawn: last.drawn.lowerBound ..< end, source: source)
                return
            }
            if last.source.upperBound == source.lowerBound, last.drawn.count == last.source.count, byteCount == source.count {
                spans[spans.count - 1] = Span(drawn: last.drawn.lowerBound ..< end, source: last.source.lowerBound ..< source.upperBound)
                return
            }
        }
        spans.append(Span(drawn: start ..< end, source: source))
    }

    /// Retains the source positions when word wrapping moves or trims a piece of a line.
    package func slice(_ range: Range<Int>) -> Self {
        var result = Self()
        for span in spans where span.drawn.overlaps(range) {
            let drawn = span.drawn.clamped(to: range)
            result.append(byteCount: drawn.count, source: span.sourceRange(for: drawn))
        }
        return result
    }
}

/// The source associated with one painted cell, including wide-glyph continuation cells.
package struct SelectableCell {
    package let owner: ObjectIdentifier
    package let source: Range<Int>

    package init(owner: ObjectIdentifier, source: Range<Int>) {
        self.owner = owner
        self.source = source
    }
}
