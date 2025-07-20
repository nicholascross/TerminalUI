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

        // Build UI inline: widgets are collected and laid out in-place
        let loop = UIEventLoop {
            Stack(axis: .vertical, spacing: 0) {
                TextAreaWidget(
                    lines: [" TerminalUI Example "],
                    isUserInteractive: false
                )
                    .frame(height: 3)

                Stack(axis: .horizontal, spacing: 1) {
                    ListWidget(items: ["Item A", "Item B", "Item C"], title: "Items")
                        .frame(width: 20)
                    Stack(axis: .vertical, spacing: 0) {
                        TextAreaWidget(lines: [
                            "Line 1: Hello, World!",
                            "Line 2: This is a text area.",
                            "Line 3: Use ↑/↓ to scroll.",
                            "Line 4: Swift TerminalUI",
                            "Line 5: Enjoy!"
                        ], title: "Details")
                        TextAreaWidget(lines: [
                            "Line 1: Hello, World!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!",
                            "Line 2: This is a text area.",
                            "Line 3: Use ↑/↓ to scroll."
                        ], title: "More Details")
                    }
                }

                TextInputWidget(prompt: "> ", title: "Input")
                    .frame(height: 3)
            }
        }

        try loop.run()
    }
}
