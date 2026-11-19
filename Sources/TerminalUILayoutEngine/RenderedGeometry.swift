import TerminalUICore

/// Borrowed geometry for synchronous pointer dispatch. Invalidation also expires captured views.
package final class RenderedGeometry {
    package private(set) var root: LayoutNode?
    private var selectableCells: [Int: [Int: SelectableCell]]

    package init(root: LayoutNode, selectableCells: [Int: [Int: SelectableCell]] = [:]) {
        self.root = root
        self.selectableCells = selectableCells
    }

    package func invalidate() {
        root = nil
        selectableCells = [:]
    }

    package func selectableCell(at mouse: MouseEvent) -> SelectableCell? {
        selectableCells[mouse.row]?[mouse.column]
    }

    /// Find the closest selectable cell in the originating text, in terminal reading order.
    package func selectionEndpoint(for owner: ObjectIdentifier, at mouse: MouseEvent) -> SelectableCell? {
        if let cell = selectableCell(at: mouse), cell.owner == owner { return cell }
        let cellLimit = 4096
        let targetRow = max(-1, min(cellLimit, mouse.row))
        let targetColumn = max(-1, min(cellLimit, mouse.column))
        // If the pointer leaves the text vertically, clamp to the start or end of that row.
        var best: (distance: (Int, Int, Int), cell: SelectableCell)?
        for (row, columns) in selectableCells {
            let column = row > targetRow ? -1 : (row < targetRow ? cellLimit : targetColumn)
            for (position, cell) in columns where cell.owner == owner {
                let distance = (abs(row - targetRow), abs(position - column), row * cellLimit + position)
                if best.map({ distance < $0.distance }) ?? true { best = (distance, cell) }
            }
        }
        return best?.cell
    }
}
