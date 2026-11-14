import TerminalUICore

package struct EditorCoordinates {
    package init() {}
    package func positions(_ characters: [Character], width: Int, multiline: Bool) -> [(column: Int, row: Int)] {
        if !multiline {
            var column = 0
            var positions: [(column: Int, row: Int)] = []
            for character in characters {
                positions.append((column, 0))
                column += max(1, CellWidth.width(of: character))
            }
            positions.append((column, 0))
            return positions
        }
        var coordinates: [(column: Int, row: Int)] = []
        var column = 0
        var row = 0
        for character in characters {
            if character == "\n" {
                if column >= width {
                    row += 1; column = 0; coordinates.append((column, row))
                } else {
                    coordinates.append((column, row)); row += 1; column = 0
                }
                continue
            }
            let charWidth = max(1, CellWidth.width(of: character))
            if column > 0, column + charWidth > width { row += 1; column = 0 }
            coordinates.append((column, row))
            column += charWidth
        }
        if column >= width { row += 1; column = 0 }
        coordinates.append((column, row))
        return coordinates
    }
}
