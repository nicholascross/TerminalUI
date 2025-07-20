import TerminalUI

@main
struct App {
    static func main() throws {
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
        let textArea2 = TextAreaWidget(lines: [
            "Line 1: Hello, World!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!",
            "Line 2: This is a text area.",
            "Line 3: Use ↑/↓ to scroll."
        ])
        let input = TextInputWidget(prompt: "> ")

        // Add a header widget to test fixed-height framing and padding
        let header = TextAreaWidget(lines: [" TerminalUI Example "])

        // Define widget set including header, list, text area, and input
        let widgets: [Widget] = [header, list, textArea, textArea2, input]

        // Build a SwiftUI-like stack layout with nested stacks, spacing, and fixed frames
        let rootLayout = Stack(axis: .vertical, spacing: 1) {
            WidgetLeaf(0)
                .frame(height: 3)
            Stack(axis: .horizontal, spacing: 1) {
                WidgetLeaf(1)
                    .frame(width: 20)
                WidgetLeaf(2)
                WidgetLeaf(3)
            }
            WidgetLeaf(4)
                .frame(height: 3)
        }

        let loop = UIEventLoop(
            widgets: widgets,
            layout: rootLayout
        )

        try loop.run()
    }
}
