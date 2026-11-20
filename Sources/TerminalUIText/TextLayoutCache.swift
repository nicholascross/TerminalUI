import TerminalUICore

/// Retains a bounded working set across scrolls, evicting the least recently used layout.
package final class TextLayoutCache {
    struct Key: Hashable {
        let texts: [String]
        let width: Int?
        let styled: Bool
        let tracksSource: Bool

        static func == (lhs: Self, rhs: Self) -> Bool {
            // Source maps use UTF-8 offsets, which can differ for canonically equivalent strings.
            lhs.width == rhs.width && lhs.styled == rhs.styled && lhs.tracksSource == rhs.tracksSource
                && lhs.texts.count == rhs.texts.count
                && zip(lhs.texts, rhs.texts).allSatisfy { $0.utf8.elementsEqual($1.utf8) }
        }
    }

    package enum Layout {
        case plain(WrappedText)
        case styled(WrappedStyledText)

        var cost: Int {
            switch self {
            case let .plain(text):
                text.lines.reduce(0) { $0 + $1.utf8.count + 32 }
                    + (text.sourceMaps?.reduce(0) { $0 + Self.cost(of: $1) } ?? 0)
            case let .styled(text):
                text.lines.reduce(0) { cost, line in
                    cost + 32 + line.runs.reduce(0) {
                        $0 + $1.text.utf8.count + MemoryLayout<WrappedStyledText.Run>.stride + Self.cost(of: $1.sourceMap)
                    }
                }
            }
        }

        private static func cost(of map: TextSourceMap?) -> Int {
            (map?.spans.count ?? 0) * MemoryLayout<TextSourceMap.Span>.stride
        }
    }

    package final class Entry {
        let key: Key
        package let layout: Layout
        let cost: Int
        weak var previous: Entry?
        weak var next: Entry?

        init(key: Key, layout: Layout) {
            self.key = key
            self.layout = layout
            cost = key.texts.reduce(0) { $0 + $1.utf8.count } + layout.cost
        }
    }

    private var entries: [Key: Entry] = [:]
    private var oldest: Entry?
    private var newest: Entry?
    package private(set) var cost = 0
    package private(set) var layoutCount = 0
    private let budget: Int

    package init(budget: Int = 4 * 1048576) {
        self.budget = max(0, budget)
    }

    package func layout(_ text: String, width: Int) -> WrappedText {
        let entry = entry(text, width: width)
        guard case let .plain(wrapped) = entry.layout else { preconditionFailure("Unexpected text layout") }
        return wrapped
    }

    package func entry(_ text: String, width: Int?, tracksSource: Bool = false, reusing cached: Entry? = nil) -> Entry {
        if let cached, cached.key.width == width, !cached.key.styled, cached.key.tracksSource == tracksSource {
            touch(cached)
            return cached
        }
        let key = Key(texts: [text], width: width, styled: false, tracksSource: tracksSource)
        return layout(key) { .plain(WrappedText(text, width: width, tracksSource: tracksSource)) }
    }

    package func layout(_ spans: [TextSpan], width: Int) -> WrappedStyledText {
        let entry = entry(spans, width: width)
        guard case let .styled(wrapped) = entry.layout else { preconditionFailure("Unexpected text layout") }
        return wrapped
    }

    package func entry(_ spans: [TextSpan], width: Int?, tracksSource: Bool = false, reusing cached: Entry? = nil) -> Entry {
        if let cached, cached.key.width == width, cached.key.styled, cached.key.tracksSource == tracksSource {
            touch(cached)
            return cached
        }
        let key = Key(texts: spans.map(\.text), width: width, styled: true, tracksSource: tracksSource)
        return layout(key) { .styled(WrappedStyledText(key.texts, width: width, tracksSource: tracksSource)) }
    }

    private func layout(_ key: Key, make: () -> Layout) -> Entry {
        if let cached = entries[key] {
            touch(cached)
            return cached
        }
        layoutCount += 1
        let entry = Entry(key: key, layout: make())
        guard entry.cost <= budget else { return entry }
        while let oldest, entries.count >= 4096 || entry.cost > budget - cost {
            unlink(oldest)
            entries.removeValue(forKey: oldest.key)
            cost -= oldest.cost
        }
        entries[key] = entry
        cost += entry.cost
        touch(entry)
        return entry
    }

    private func touch(_ entry: Entry) {
        guard newest !== entry else { return }
        unlink(entry)
        entry.previous = newest
        newest?.next = entry
        newest = entry
        if oldest == nil { oldest = entry }
    }

    private func unlink(_ entry: Entry) {
        entry.previous?.next = entry.next
        entry.next?.previous = entry.previous
        if oldest === entry { oldest = entry.next }
        if newest === entry { newest = entry.previous }
        entry.previous = nil
        entry.next = nil
    }
}
