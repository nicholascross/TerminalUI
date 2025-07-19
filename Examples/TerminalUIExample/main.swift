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

        // Build dynamic widget set
        let list = ListWidget(items: ["Item A", "Item B", "Item C"])
        let input = TextInputWidget(prompt: "> ")
        let widgets: [Widget] = [list, input]
        let loop = UIEventLoop(rows: rows, cols: cols, widgets: widgets)
        try loop.run()
    }
}
