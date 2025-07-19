import TerminalUI

@main
struct App {
    static func main() throws {
        let (rows, cols) = Terminal.getTerminalSize()
        Terminal.clearScreen()
        defer {
            Terminal.showCursor()
            Terminal.clearScreen()
        }

        // Print resize events
        Terminal.onResize = { rows, cols in
            Terminal.clearScreen()
            Terminal.moveCursor(row: 1, col: 1)
            print("Resized to \(rows)x\(cols)")
        }

        let loop = UIEventLoop(rows: rows, cols: cols)
        // Pre-populate with some items
        loop.listWidget.items = ["Item A", "Item B", "Item C"]
        try loop.run()
    }
}
