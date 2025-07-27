import Darwin.C
import Foundation

/// Which style of box‑drawing characters to use for borders.
public enum BorderStyle {
    /// Unicode box‑drawing (─│┌┐└┘)
    case unicode
    /// ASCII fallback (+, -, |)
    case ascii
}

/// A styled cell in the screen buffer.
public struct Cell: Equatable {
    public let char: Character
    public let style: Style
}

/// Manages a virtual screen buffer and rendering to terminal.
public class Renderer {
    private var buffer: [[Cell]]
    /// Last drawn buffer state used for diff redraws.
    private var lastBuffer: [[Cell]]

    /// Initialize renderer with given dimensions.
    public init(rows: Int, cols: Int) {
        let emptyCell = Cell(char: " ", style: [])
        buffer = Array(
            repeating: Array(repeating: emptyCell, count: cols),
            count: rows
        )
        // Initialize lastBuffer to match initial empty buffer
        lastBuffer = buffer
    }

    /// Clear the entire cell buffer (fills with spaces and default style).
    public func clearBuffer() {
        let empty = Cell(char: " ", style: [])
        for row in buffer.indices {
            for col in buffer[row].indices {
                buffer[row][col] = empty
            }
        }
    }

    /// Set a single cell at (row, col) in the buffer.
    public func setCell(row: Int, col: Int, char: Character, style: Style = []) {
        guard
            row >= 0, row < buffer.count,
            col >= 0, col < buffer[row].count
        else {
            return
        }
        buffer[row][col] = Cell(char: char, style: style)
    }

    /// Draw a rectangular border around the given region.
    public func drawBorder(
        _ region: Region,
        style borderStyle: BorderStyle = .unicode,
        cellStyle: Style = []
    ) {
        let horizontal, vertical, topLeft, topRight, bottomLeft, bottomRight: Character

        switch borderStyle {
        case .unicode:
            horizontal = "─"
            vertical = "│"
            topLeft = "┌"
            topRight = "┐"
            bottomLeft = "└"
            bottomRight = "┘"
        case .ascii:
            horizontal = "-"
            vertical = "|"
            topLeft = "+"
            topRight = "+"
            bottomLeft = "+"
            bottomRight = "+"
        }

        let top = region.top, left = region.left
        let bottom = top + region.height - 1
        let right = left + region.width - 1

        // Top/bottom edges (only if width >= 2).
        if right > left {
            for columnIndex in (left + 1) ..< right {
                setCell(row: top, col: columnIndex, char: horizontal, style: cellStyle)
                setCell(row: bottom, col: columnIndex, char: horizontal, style: cellStyle)
            }
        }
        // Left/right edges (only if height >= 2).
        if bottom > top {
            for rowIndex in (top + 1) ..< bottom {
                setCell(row: rowIndex, col: left, char: vertical, style: cellStyle)
                setCell(row: rowIndex, col: right, char: vertical, style: cellStyle)
            }
        }
        // Corners (if region is at least 1x1).
        if region.width > 0, region.height > 0 {
            setCell(row: top, col: left, char: topLeft, style: cellStyle)
            if right > left {
                setCell(row: top, col: right, char: topRight, style: cellStyle)
            }
            if bottom > top {
                setCell(row: bottom, col: left, char: bottomLeft, style: cellStyle)
                if right > left {
                    setCell(row: bottom, col: right, char: bottomRight, style: cellStyle)
                }
            }
        }
    }

    /// Flush the buffer to the terminal, respecting per-cell style.
    public func blit() {
        // Only redraw rows that have changed since last blit.
        for (rowIndex, row) in buffer.enumerated() {
            guard rowIndex < lastBuffer.count, row == lastBuffer[rowIndex] else {
                Terminal.moveCursor(row: rowIndex + 1, col: 1)
                var skip = 0
                for cell in row {
                    if skip > 0 {
                        skip -= 1
                        continue
                    }
                    Terminal.setStyle(cell.style)
                    Terminal.output.write(String(cell.char))
                    let width = cell.char.terminalColumnWidth
                    if width > 1 {
                        skip = width - 1
                    }
                }
                Terminal.resetStyle()
                continue
            }
        }
        fflush(stdout)
        lastBuffer = buffer
    }
}
