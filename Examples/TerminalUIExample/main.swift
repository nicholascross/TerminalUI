import TerminalUI

let terminal = Terminal()
defer {
    terminal.showCursor()
    terminal.clearScreen()
}

// Build an interactive UI with a list, detail view, and text input
// Press Ctrl-D to submit input, or 'q'/Ctrl-C to quit
let details = TextAreaWidget(
    text: """
        Select an item from the list on the left.
        Use ↑/↓ to navigate, and type below to send input.
        """,
    title: "Details"
)

details.isDisabled = true

let list = ListWidget(items: ["Apple", "Banana", "Cherry"], title: "Fruits")
list.onSelect = { _, selection in
    details.text = "You selected: \(selection)"
}

let input = TextInputWidget(prompt: "> ", title: "Command")
let loop = UIEventLoop(terminal: terminal) {
    Stack(axis: .vertical, spacing: 0) {
        TextAreaWidget(
            text: " TerminalUI Demo ",
            isUserInteractive: false
        )
        .frame(height: 3)

        Stack(axis: .horizontal, spacing: 1) {
            list.frame(width: 20)
            details
        }

        input.frame(height: 3)
    }
}

// Handle submitted text (Ctrl-D)
loop.onInput = { text in
    details.text = "You entered: \(text)"
}

try loop.run()
