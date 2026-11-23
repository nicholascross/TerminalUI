// Coordinates conventionally use x and y.
// swiftlint:disable identifier_name
/// A clipped drawing surface. Text is always sanitized before entering the grid.
public struct Canvas {
    public private(set) var grid: CellGrid
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    private let rowOffset: Int
    /// Indexed by grid-local row and column, like the cells in the backing grid.
    package private(set) var selectableCells: [Int: [Int: SelectableCell]] = [:]
    package var visibleRows: Range<Int> { rowOffset..<(rowOffset + grid.height) }

    public init(width: Int, height: Int) {
        let grid = CellGrid(width: width, height: height)
        self.grid = grid
        x = 0
        y = 0
        self.width = grid.width
        self.height = grid.height
        rowOffset = 0
    }

    public init(grid: CellGrid) {
        self.grid = grid
        x = 0
        y = 0
        width = grid.width
        height = grid.height
        rowOffset = 0
    }

    /// Keeps content coordinates while allocating storage only for the viewport.
    package init(width: Int, height: Int, viewport: Range<Int>) {
        grid = CellGrid(width: width, height: viewport.count)
        x = 0
        y = 0
        self.width = grid.width
        self.height = height
        rowOffset = viewport.lowerBound
    }

    package func cell(atX column: Int, y row: Int) -> Cell? { grid[column, row - rowOffset] }

    /// Draw on one row. A wide glyph crossing the clip boundary becomes a replacement cell.
    public mutating func write(_ text: String, x: Int, y: Int, style: TextStyle = TextStyle(),
                               clipWidth: Int? = nil) {
        write(text, x: x, y: y, style: style, clipWidth: clipWidth, selection: nil)
    }

    package enum SelectionSource {
        case mapped(ObjectIdentifier, TextSourceMap)
        case cell(SelectableCell)
    }

    package mutating func write(_ text: String, x: Int, y: Int, style: TextStyle,
                                clipWidth: Int?, selection: SelectionSource?) {
        guard visibleRows.contains(y) else { return }
        let y = y - rowOffset
        let limit = min(width, max(0, clipWidth.map { x.addingReportingOverflow($0).overflow ? width : x + $0 } ?? width))
        var column = x
        var spans: ArraySlice<TextSourceMap.Span> = []
        var byteOffset = 0
        if case let .mapped(_, map) = selection { spans = map.spans[...] }
        for char in text {
            guard column < limit else { break }
            let source: SelectableCell?
            switch selection {
            case nil: source = nil
            case let .cell(cell): source = cell
            case let .mapped(owner, _):
                let end = byteOffset + char.utf8.count
                var range: Range<Int>?
                while let span = spans.first, span.drawn.lowerBound < end {
                    let source = span.sourceRange(for: byteOffset ..< end)
                    range = (range?.lowerBound ?? source.lowerBound) ..< source.upperBound
                    if span.drawn.upperBound > end { break }
                    spans.removeFirst()
                }
                source = range.map { SelectableCell(owner: owner, source: $0) }
                byteOffset = end
            }
            let safe: Character = CellWidth.isSafe(char) && CellWidth.width(of: char) > 0 ? char : "�"
            let characterWidth = CellWidth.width(of: safe)
            if column == -1 && characterWidth == 2 && limit > 0 {
                eraseFootprint(x: 0, y: y)
                grid.put(Cell(grapheme: "�", width: 1, style: style), x: 0, y: y)
                if let source { selectableCells[y, default: [:]][0] = source }
            } else if column >= 0 {
                eraseFootprint(x: column, y: y)
                if characterWidth == 2, column + 1 < limit {
                    eraseFootprint(x: column + 1, y: y)
                    grid.put(Cell(grapheme: String(safe), width: 2, style: style), x: column, y: y)
                    grid.put(Cell(grapheme: "", width: 0, style: style), x: column + 1, y: y)
                    if let source { selectableCells[y, default: [:]][column + 1] = source }
                } else {
                    grid.put(Cell(grapheme: characterWidth == 2 ? "�" : String(safe), width: 1, style: style), x: column, y: y)
                }
                if let source { selectableCells[y, default: [:]][column] = source }
            }
            column += characterWidth
        }
    }

    /// Selecting through the rightmost painted glyph of a clipped line reaches its source end.
    package mutating func extendSelection(through sourceEnd: Int, owner: ObjectIdentifier, row: Int, columns: Range<Int>) {
        let y = row - rowOffset
        let visible = columns.clamped(to: 0 ..< width)
        guard let column = visible.reversed().first(where: { selectableCells[y]?[$0]?.owner == owner }),
              let cell = selectableCells[y]?[column], cell.source.upperBound < sourceEnd else { return }
        let extended = SelectableCell(owner: owner, source: cell.source.lowerBound ..< sourceEnd)
        selectableCells[y]?[column] = extended
        if column > visible.lowerBound, grid[column, y]?.width == 0 {
            selectableCells[y]?[column - 1] = extended
        }
    }

    public mutating func clear(x: Int, y: Int, width: Int, height: Int) {
        guard width > 0, height > 0 else { return }
        let startX = max(0, min(self.width, x))
        let startY = max(rowOffset, min(self.height, y))
        let endX = min(self.width, x.addingReportingOverflow(width).overflow ? self.width : x + width)
        let endY = min(visibleRows.upperBound, y.addingReportingOverflow(height).overflow ? self.height : y + height)
        guard startX < endX, startY < endY else { return }
        for row in startY..<endY {
            for column in startX..<endX { eraseFootprint(x: column, y: row - rowOffset) }
        }
    }

    /// Fills complete rows, including blank cells, using the same clipping as text.
    public mutating func fill(x: Int, y: Int, width: Int, height: Int, style: TextStyle) {
        let startX = max(0, x), startY = max(rowOffset, y)
        let endX = min(self.width, x.addingReportingOverflow(max(0, width)).overflow ? self.width : x + max(0, width))
        let endY = min(visibleRows.upperBound, y.addingReportingOverflow(max(0, height)).overflow ? self.height : y + max(0, height))
        guard startX < endX, startY < endY else { return }
        for row in startY..<endY {
            let localRow = row - rowOffset
            eraseFootprint(x: startX, y: localRow)
            eraseFootprint(x: endX - 1, y: localRow)
            grid.fill(startX..<endX, row: localRow, style: style)
            if selectableCells[localRow] != nil {
                for column in startX..<endX { selectableCells[localRow]?[column] = nil }
                if selectableCells[localRow]?.isEmpty == true { selectableCells[localRow] = nil }
            }
        }
    }

    package mutating func dimBackdrop(x: Int, y: Int, width: Int, height: Int, faintEnabled: Bool) {
        let columns = (x ..< (x + width)).clamped(to: 0 ..< self.width)
        let rows = (y ..< (y + height)).clamped(to: visibleRows)
        guard !columns.isEmpty, !rows.isEmpty else { return }
        grid.dimBackdrop(columns, rows: (rows.lowerBound - rowOffset) ..< (rows.upperBound - rowOffset), faintEnabled: faintEnabled)
    }

    private mutating func eraseFootprint(x: Int, y: Int) {
        guard let old = grid[x, y] else { return }
        if old.width == 0 {
            grid.put(.blank, x: x - 1, y: y)
            selectableCells[y]?[x - 1] = nil
        }
        if old.width == 2 {
            grid.put(.blank, x: x + 1, y: y)
            selectableCells[y]?[x + 1] = nil
        }
        grid.put(.blank, x: x, y: y)
        selectableCells[y]?[x] = nil
    }
}

// swiftlint:enable identifier_name
