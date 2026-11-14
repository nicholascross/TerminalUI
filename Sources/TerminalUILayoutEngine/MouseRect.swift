import TerminalUICore

/// Internal cell bounds shared by painting and pointer routing.
package struct MouseRect {
    package let column: Int
    package let row: Int
    package let width: Int
    package let height: Int

    package init(column: Int, row: Int, width: Int, height: Int) {
        self.column = column
        self.row = row
        self.width = width
        self.height = height
    }

    package func contains(_ event: MouseEvent) -> Bool {
        event.column >= column && event.column < column + width && event.row >= row && event.row < row + height
    }

    package func intersecting(_ other: Self) -> Self {
        let left = max(column, other.column), top = max(row, other.row)
        return Self(column: left, row: top, width: max(0, min(column + width, other.column + other.width) - left),
                    height: max(0, min(row + height, other.row + other.height) - top))
    }
}
