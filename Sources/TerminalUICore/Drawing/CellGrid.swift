// Coordinates conventionally use x and y.
// swiftlint:disable identifier_name
/// A complete terminal frame. All dimensions are bounded to avoid excessive allocations.
public struct CellGrid: Equatable, Sendable {
    public let width: Int
    public let height: Int
    private var cells: [Cell]

    public init(width: Int, height: Int) {
        self.width = max(0, min(width, 4096))
        let maximumRows = self.width == 0 ? 4096 : 1_048_576 / self.width
        self.height = max(0, min(height, 4096, maximumRows))
        cells = Array(repeating: .blank, count: self.width * self.height)
    }

    public subscript(x: Int, y: Int) -> Cell? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return cells[y * width + x]
    }

    internal mutating func put(_ cell: Cell, x: Int, y: Int) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        cells[y * width + x] = cell
    }

    /// The caller clips the range and erases wide glyphs at its boundaries.
    mutating func fill(_ columns: Range<Int>, row: Int, style: TextStyle) {
        let cell = Cell(grapheme: " ", width: 1, style: style)
        for column in columns { cells[row * width + column] = cell }
    }

    /// Paints selection styling on a snapshot while retaining graphemes and their footprints.
    package func highlighting(
        _ selection: SelectableCell, in cells: [Int: [Int: SelectableCell]], style: TextStyle,
    ) -> Self {
        var result = self
        for (row, columns) in cells {
            for (column, cell) in columns where cell.owner == selection.owner && cell.source.overlaps(selection.source) {
                guard var painted = self[column, row] else { continue }
                painted.style = style
                result.put(painted, x: column, y: row)
            }
        }
        return result
    }

    /// Plain text rows for snapshots; continuation cells are represented by the leading glyph.
    public var lines: [String] {
        (0..<height).map { y in
            (0..<width).compactMap { x -> String? in
                guard let cell = self[x, y], cell.width != 0 else { return nil }
                return cell.grapheme
            }.joined()
        }
    }
}

// swiftlint:enable identifier_name
