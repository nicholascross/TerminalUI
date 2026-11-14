import TerminalUICore

package struct TextMetrics {
    package init() {}
    package func truncate(_ text: String, width: Int) -> String {
        guard width > 0 else { return "" }
        guard cellLength(text) > width else { return text }
        var result = ""
        var used = 0
        for character in text {
            let size = max(1, CellWidth.width(of: character))
            if used + size > width - 1 { break }
            result.append(character)
            used += size
        }
        return result + "…"
    }

    package func cellLength(_ text: String) -> Int {
        text.prefix(4096).reduce(0) { min(4096, $0 + max(1, CellWidth.width(of: $1))) }
    }
}
