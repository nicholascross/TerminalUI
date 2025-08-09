import TerminalUI

@main
struct TerminalUIExample {
    static func main() async throws {
        let terminal = Terminal()
        defer {
            terminal.showCursor()
            terminal.clearScreen()
        }

        // Build an interactive UI with a spinner, horizontal menu, a list, detail view, and text input
        // Press Ctrl-D to submit input, or 'q'/Ctrl-C to quit
        // The spinner animates on each global tick event.
        let details = TextAreaWidget(
            text: """
                Select an item from the list on the left.
                Use ↑/↓ to navigate, and type below to send input.
                """,
            title: "Details"
        )
        details.isDisabled = true

        // Horizontal menu bar
        let menu = ListWidget(items: ["File", "Edit", "View", "Help"], title: "Menu")
        menu.orientation = .horizontal
        menu.onSelect = { indices, selections in
            if let sel = selections.first {
                details.text = "Menu selected: \(sel)"
            }
        }

        let list = ListWidget(items: ["Apple", "Banana", "Cherry"], title: "Fruits")
        // Enable multiple selection: press space to toggle items (underlined when selected)
        list.allowsMultipleSelection = true
        list.onSelect = { _, selections in
            details.text = selections.isEmpty
                ? "No fruits selected"
                : "Selected fruits: \(selections.joined(separator: ", "))"
        }

        let input = TextInputWidget(prompt: "> ", title: "Command")
        // Handle submitted text (Ctrl-D)
        input.onSubmit = { text in
            details.text = "You entered: \(text)"
        }

        let loop = UIEventLoop(terminal: terminal) {
            Stack(axis: .vertical, spacing: 0) {
                Stack(axis: .horizontal, spacing: 0) {
                    SpinnerWidget().frame(width: 3)
                    TextAreaWidget(
                        text: " TerminalUI Demo ",
                        isUserInteractive: false,
                        isBorderHidden: true
                    )
                }.frame(height: 3)

                menu.frame(height: 3)

                Stack(axis: .horizontal, spacing: 1) {
                    list.frame(width: 20)
                    details
                }

                input.expanding(maxHeight: 8)
            }
        }

        try await loop.run()
    }
}
