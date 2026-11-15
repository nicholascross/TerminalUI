import TerminalUICore
import TerminalUIInteraction
import TerminalUILayoutEngine
import TerminalUIText

struct TablePainter {
    let states: WidgetStateStore
    let allocation: LayoutAllocator
    let metrics: TextMetrics

    func draw(node: LayoutNode, context: ElementPaintContext, canvas: inout Canvas) {
        guard case let .table(id, columns, rows, selected, bordered) = context.element.kind else { return }
        let element = context.element
        let focusedID = context.focusedID
        let originX = context.originX
        let originY = context.originY
        let contentWidth = context.contentWidth
        let contentHeight = context.contentHeight
        let bounds = context.bounds
        let manuallyScrolled = context.manuallyScrolled
        func resolved(_ role: TextRole, state: TextRole? = nil) -> TextStyle {
            context.resolved(role, state: state)
        }
        let stateID = "table:" + id
        let rowHeight = max(0, contentHeight - (bordered ? 4 : 1))
        states[stateID].viewport.height = rowHeight
        states[stateID].viewport.limit = rowHeight > 0 ? max(0, rows.count - rowHeight) : 0
        var offset = min(max(0, states[stateID].viewport.offset ?? 0), states[stateID].viewport.limit ?? 0)
        if !manuallyScrolled.contains(stateID), rowHeight > 0, let index = rows.firstIndex(where: { $0.id == selected }) {
            if index < offset { offset = index }
            if index >= offset + rowHeight { offset = index - rowHeight + 1 }
        }
        states[stateID].viewport.offset = offset
        let widths = allocation.tableWidths(columns, available: max(0, contentWidth - (bordered ? 4 : 2)))
        let left = bordered ? 1 : 0
        let headerRow = bordered ? 1 : 0
        let firstRow = bordered ? 3 : 1
        if bordered { drawBorder(widths: widths, context: context, canvas: &canvas) }
        func drawCells(_ cells: [String], row: Int, style: TextStyle) {
            var position = left + 2
            for (index, width) in widths.enumerated() {
                guard row < contentHeight, position < contentWidth - left else { break }
                if width > 0, index < cells.count {
                    canvas.write(metrics.truncate(String(cells[index].prefix(100000).prefix { !$0.isNewline }), width: width),
                                 x: originX + position, y: originY + row, style: style, clipWidth: width)
                }
                position += width + 1
            }
        }
        if !bordered || contentHeight > 2 {
            drawCells(columns.map(\.title), row: headerRow, style: resolved(.heading))
        }
        let focused = focusedID == id
        let hasSelection = rows.contains { $0.id == selected }
        if rows.isEmpty, focused, rowHeight > 0 {
            canvas.write("> (empty)", x: originX + left, y: originY + firstRow,
                         style: resolved(.focused), clipWidth: max(0, contentWidth - 2 * left))
        }
        for (index, row) in rows.dropFirst(offset).prefix(rowHeight).enumerated() {
            node.mouse?.rows.append((row.id, MouseRect(column: bounds.column + left, row: bounds.row + index + firstRow,
                                                       width: max(0, contentWidth - 2 * left), height: 1)))
            let chosen = row.id == selected
            let focusRow = focused && (chosen || (!hasSelection && index == 0))
            let style = resolved(element.textRole, state: chosen || focusRow ? .selection : nil)
            canvas.write(focusRow ? ">" : (chosen ? "•" : " "), x: originX + left,
                         y: originY + index + firstRow, style: style, clipWidth: max(0, contentWidth - 2 * left))
            drawCells(row.cells, row: index + firstRow, style: style)
        }
    }

    private func drawBorder(widths: [Int], context: ElementPaintContext, canvas: inout Canvas) {
        let theme = context.theme
        let contentWidth = context.contentWidth
        let contentHeight = context.contentHeight
        func resolved(_ role: TextRole, state: TextRole? = nil) -> TextStyle {
            context.resolved(role, state: state)
        }
        func write(_ text: String, _ row: Int, _ col: Int = 0, style: TextStyle? = nil) {
            context.write(text, row: row, column: col, style: style, canvas: &canvas)
        }
        let borderStyle = resolved(.border, state: context.focusedID == context.element.controlID ? .activeBorder : nil)
        if contentHeight > 1 {
            for row in 1 ..< contentHeight - 1 {
                write(theme.borders.vertical, row, style: borderStyle)
                if contentWidth > 1 { write(theme.borders.vertical, row, contentWidth - 1, style: borderStyle) }
            }
        }
        func horizontal(_ row: Int, _ left: String, _ right: String, _ junction: String) {
            guard row < contentHeight else { return }
            write(left, row, style: borderStyle)
            if contentWidth > 2 {
                write(String(repeating: theme.borders.horizontal, count: contentWidth - 2), row, 1, style: borderStyle)
            }
            if contentWidth > 1 { write(right, row, contentWidth - 1, style: borderStyle) }
            var position = 3
            for width in widths.dropLast() {
                position += width
                if position < contentWidth - 1 { write(junction, row, position, style: borderStyle) }
                position += 1
            }
        }
        horizontal(0, theme.borders.topLeft, theme.borders.topRight, theme.borders.topJoin)
        if contentHeight > 2 { horizontal(2, theme.borders.leftJoin, theme.borders.rightJoin, theme.borders.cross) }
        if contentHeight > 1 { horizontal(contentHeight - 1, theme.borders.bottomLeft, theme.borders.bottomRight, theme.borders.bottomJoin) }
        var position = 3
        for width in widths.dropLast() {
            position += width
            if position < contentWidth - 1, contentHeight > 2 {
                for row in 1 ..< contentHeight - 1 where row != 2 {
                    write(theme.borders.vertical, row, position, style: borderStyle)
                }
            }
            position += 1
        }
    }
}
