import Foundation
import Darwin.C

/// A styled cell in the screen buffer.
public struct Cell {
    public let char: Character
    public let style: Style
}

/// Manages a virtual screen buffer and rendering to terminal.
public class Renderer {
    private var buffer: [[Cell]]

    /// Initialize renderer with given dimensions.
    public init(rows: Int, cols: Int) {
        let emptyCell = Cell(char: " ", style: [])
        self.buffer = Array(repeating: Array(repeating: emptyCell, count: cols), count: rows)
    }

    /// Render the given lines to the screen buffer and flush.
    public func render(lines: [String]) {
        Terminal.clearScreen()
        for (i, line) in lines.enumerated() {
            Terminal.moveCursor(row: i + 1, col: 1)
            print(line, terminator: "")
        }
        fflush(stdout)
    }

    /// Redraw only a specific region of lines.
    public func redrawRegion(fromLine: Int, toLine: Int) {
        for row in fromLine...toLine {
            let line = String(buffer[row].map { $0.char })
            Terminal.moveCursor(row: row + 1, col: 1)
            print(line, terminator: "")
        }
        fflush(stdout)
    }
}
