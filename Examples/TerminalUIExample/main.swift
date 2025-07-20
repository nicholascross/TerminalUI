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
        let textArea = TextAreaWidget(lines: [
            "Line 1: Hello, World!",
            "Line 2: This is a text area.",
            "Line 3: Use ↑/↓ to scroll.",
            "Line 4: Swift TerminalUI",
            "Line 5: Enjoy!"
        ])

        let input = TextInputWidget(prompt: "> ")

        let widgets: [Widget] = [list, textArea, input]

        // Build a SwiftUI-like stack layout instead of manual constraints
        let rootLayout = VStack(spacing: 1) {
            HStack(spacing: 1) {
                WidgetLeaf(0)
                WidgetLeaf(1)
            }
            WidgetLeaf(2)
                .frame(height: 3)
        }

        let loop = UIEventLoop(rows: rows, cols: cols,
                               widgets: widgets,
                               layout: rootLayout)
        try loop.run()
    }
}
