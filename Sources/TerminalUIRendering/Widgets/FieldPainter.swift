import TerminalUICore
import TerminalUIInteraction
import TerminalUILayout
import TerminalUIText

struct FieldPainter {
    let states: WidgetStateStore
    let coordinates: EditorCoordinates

    func draw(node: LayoutNode, context: ElementPaintContext, canvas: inout Canvas) {
        guard case let .field(id, value, placeholder, multiline) = context.element.kind else { return }
        let element = context.element
        let focusedID = context.focusedID
        let originX = context.originX
        let originY = context.originY
        let contentWidth = context.contentWidth
        let contentHeight = context.contentHeight
        let manuallyScrolled = context.manuallyScrolled
        func resolved(_ role: TextRole, state: TextRole? = nil) -> TextStyle {
            context.resolved(role, state: state)
        }
        func write(_ text: String, _ row: Int, _ col: Int = 0, style: TextStyle? = nil) {
            context.write(text, row: row, column: col, style: style, canvas: &canvas)
        }
        let fieldRole: TextRole = if case .normal = element.textRole { .field } else { element.textRole }
        let stateID = (multiline ? "editor:" : "field:") + id
        if states[stateID].viewport.width != contentWidth { states[stateID].editor.preferredColumn = nil }
        states[stateID].viewport.width = contentWidth
        let chars = Array(value.prefix(100000))
        let caret = min(states[stateID].editor.caret ?? chars.count, chars.count)
        let coordinates = coordinates.positions(chars, width: contentWidth, multiline: multiline)
        let caretCoordinate = coordinates[caret]
        var verticalOffset = multiline ? max(0, states[stateID].viewport.offset ?? 0) : 0
        if multiline {
            states[stateID].viewport.height = contentHeight
            states[stateID].viewport.limit = max(0, coordinates[chars.count].1 - contentHeight + 1)
            verticalOffset = min(verticalOffset, states[stateID].viewport.limit ?? 0)
            if !manuallyScrolled.contains(stateID) {
                if caretCoordinate.1 < verticalOffset { verticalOffset = caretCoordinate.1 }
                if caretCoordinate.1 >= verticalOffset + contentHeight {
                    verticalOffset = max(0, caretCoordinate.1 - contentHeight + 1)
                }
            }
            states[stateID].viewport.offset = verticalOffset
        }
        let horizontalOffset = multiline ? 0 : max(0, caretCoordinate.0 - contentWidth + 1)
        node.mouse?.horizontalOffset = horizontalOffset
        node.mouse?.verticalOffset = verticalOffset
        if chars.isEmpty, !placeholder.isEmpty { write(placeholder, 0, style: resolved(.muted)) }
        let anchor = min(states[stateID].editor.selection ?? caret, chars.count)
        let selection = min(anchor, caret) ..< max(anchor, caret)
        for (index, char) in chars.enumerated() where char != "\n" {
            let (cellX, cellY) = coordinates[index]
            let localX = cellX - horizontalOffset, localY = cellY - verticalOffset
            guard localY >= 0, localY < contentHeight, localX < contentWidth else { continue }
            var style = resolved(fieldRole, state: selection.contains(index) ? .selection : nil)
            if focusedID == id, index == caret { style.reversed.toggle() }
            if localX == -1, CellWidth.width(of: char) == 2 {
                write("�", localY, style: style)
                continue
            }
            guard localX >= 0 else { continue }
            canvas.write(String(char), x: originX + localX, y: originY + localY,
                         style: style, clipWidth: contentWidth - localX)
        }
        if focusedID == id, caret == chars.count || chars[caret] == "\n" {
            let localX = caretCoordinate.0 - horizontalOffset, localY = caretCoordinate.1 - verticalOffset
            if localX >= 0, localX < contentWidth, localY >= 0, localY < contentHeight {
                let cursor = chars.isEmpty && !placeholder.isEmpty ? String(placeholder.prefix(1)) : " "
                canvas.write(cursor, x: originX + localX, y: originY + localY, style: resolved(.cursor), clipWidth: contentWidth - localX)
            }
        }
    }
}
