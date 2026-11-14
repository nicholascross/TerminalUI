import TerminalUICore
import TerminalUIInteraction
import TerminalUILayoutEngine
import TerminalUIText

struct ListPainter {
    let states: WidgetStateStore
    let textLayouts: TextLayoutCache
    let metrics: TextMetrics

    func draw(node: LayoutNode, context: ElementPaintContext, canvas: inout Canvas) {
        guard case let .list(id, rows, selected) = context.element.kind else { return }
        let element = context.element
        let theme = context.theme
        let focusedID = context.focusedID
        let contentWidth = context.contentWidth
        let contentHeight = context.contentHeight
        let bounds = context.bounds
        let manuallyScrolled = context.manuallyScrolled
        func resolved(_ role: TextRole, state: TextRole? = nil) -> TextStyle {
            context.resolved(role, state: state)
        }
        func write(_ text: String, _ row: Int, _ col: Int = 0, style: TextStyle? = nil) {
            context.write(text, row: row, column: col, style: style, canvas: &canvas)
        }
        let stateID = "list:" + id
        let lineLimit = min(element.listLineLimit, contentHeight)
        let lines = rows.map { textLayouts.layout($0.displayTitle, width: max(1, contentWidth - 2)).lines }
        let heights = lines.map { min(lineLimit, $0.count) }
        var limit = max(0, rows.count - 1)
        while limit > 0, heights[(limit - 1)...].reduce(0, +)
            + (rows.count - limit) * element.listRowSpacing <= contentHeight
        {
            limit -= 1
        }
        states[stateID].viewport.limit = limit
        var offset = min(max(0, states[stateID].viewport.offset ?? 0), limit)
        if !manuallyScrolled.contains(stateID), let selection = rows.firstIndex(where: { $0.id == selected }) {
            offset = min(offset, selection)
            while offset < selection, heights[offset ... selection].reduce(0, +)
                + (selection - offset) * element.listRowSpacing > contentHeight
            {
                offset += 1
            }
        }
        // Fill upward after a resize or removal, without reserving unused wrap lines.
        while offset > 0, heights[(offset - 1)...].reduce(0, +)
            + (rows.count - offset) * element.listRowSpacing <= contentHeight
        {
            offset -= 1
        }
        states[stateID].viewport.offset = offset
        let focused = focusedID == id
        let hasSelection = rows.contains { $0.id == selected }
        if rows.isEmpty, focused { write("> (empty)", 0, style: theme.focused) }
        var position = 0
        var visibleRows = 0
        for index in offset ..< rows.count where position < contentHeight {
            let row = rows[index]
            let isSelected = row.id == selected
            let isFocusRow = focused && (isSelected || (!hasSelection && index == offset))
            let marker = isFocusRow ? ">" : (isSelected ? "•" : " ")
            let state: TextRole? = !row.isEnabled ? .disabled : (isSelected || isFocusRow ? .selection : nil)
            let height = min(heights[index], contentHeight - position)
            node.mouse?.rows.append((row.id, MouseRect(column: bounds.column, row: bounds.row + position,
                                                       width: contentWidth, height: height)))
            for (lineIndex, line) in lines[index].prefix(height).enumerated() {
                let text = lineIndex == height - 1 && lines[index].count > height
                    ? metrics.truncate(lines[index].dropFirst(lineIndex).joined(separator: " "), width: max(1, contentWidth - 2)) : line
                let label = (lineIndex == 0 ? "\(marker) " : "  ") + text
                let padding = String(repeating: " ", count: max(0, contentWidth - metrics.cellLength(label)))
                write(label + padding, position + lineIndex, style: resolved(element.textRole, state: state))
            }
            position += height + element.listRowSpacing
            visibleRows += 1
        }
        states[stateID].viewport.height = max(1, visibleRows)
    }
}
