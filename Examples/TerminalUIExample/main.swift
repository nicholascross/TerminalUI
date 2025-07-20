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
        }

        // Build UI inline: widgets are collected and laid out in-place
        // Prepare list and details for selection updates
        let details = TextAreaWidget(
            text: """
            Line 1: Hello, World!
            Line 2: This is a text area.
            Line 3: Use ↑/↓ to scroll.
            Line 4: Swift TerminalUI
            Line 5: Enjoy!
            """,
            title: "Details"
        )

        let list = ListWidget(items: ["Item A", "Item B", "Item C"], title: "Items")
        list.onSelect = { _, item in
            details.text = item
        }

        let loop = UIEventLoop {
            Stack(axis: .vertical, spacing: 0) {
                TextAreaWidget(
                    text: " TerminalUI Example ",
                    isUserInteractive: false
                )
                .frame(height: 3)

                Stack(axis: .horizontal, spacing: 1) {
                    list.frame(width: 20)
                    Stack(axis: .vertical, spacing: 0) {
                        details
                        TextAreaWidget(
                            text: """
                            Line 1: Hello, World!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                            Line 2: This is a text area.
                            Line 3: Use ↑/↓ to scroll.
                            """,
                            title: "More Details"
                        )
                    }
                }

                TextInputWidget(prompt: "> ", title: "Input")
                    .frame(height: 3)
            }
        }

        try loop.run()
    }
}
