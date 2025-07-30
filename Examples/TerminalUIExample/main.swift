import TerminalUI

let terminal = Terminal()
terminal.clearScreen()
defer {
    terminal.showCursor()
    terminal.clearScreen()
}

// Define the UI layout using stacks for flexible arrangement
// Prepare list and detail view for selection updates
let details = TextAreaWidget(
    text: """
    Use TAB to focus the list, details, and input areas.
    Select an item in the list; its details will appear here.
    Scroll within this pane using ↑ and ↓ if content exceeds view.
    """,
    title: "Details"
)

let list = ListWidget(items: ["Item A", "Item B", "Item C"], title: "Items")
list.onSelect = { _, item in
    details.text = item
}

// Create a text-input widget and hook its submissions into the list
let input = TextInputWidget(prompt: "> ", title: "Input")
let loop = UIEventLoop(terminal: terminal) {
    Stack(axis: .vertical, spacing: 0) {
        // Top banner with usage instructions (non-interactive)
        TextAreaWidget(
            text: """
            TerminalUI Example

            • Press TAB to switch focus between widgets.
            • Use ↑/↓ to navigate lists and scroll text areas.
            • In the input box below, type and press Enter to submit.
            """,
            isUserInteractive: false
        )
        .frame(height: 6)

        Stack(axis: .horizontal, spacing: 1) {
            list.frame(width: 20)
            Stack(axis: .vertical, spacing: 0) {
                details
                TextAreaWidget(
                    text: """
                    Use TAB to focus the list, details, and input areas.
                    Inspect additional information about the selected item here.
                    Use ↑ and ↓ to scroll through this content if needed.

                    The text input box below allows you to enter text that will appear in the list.
                    """,
                    title: "More Details"
                )
            }
        }

        input.frame(height: 3)
    }
}

// Route submitted text into the demo list
loop.onInput = { text in
    list.items.append(text)
}

try loop.run()
