# TerminalUI

Minimal terminal UI toolkit in Swift.

## Features

- Terminal control: raw mode, cursor, styling, size detection
- Input parsing: character keys, arrow keys, backspace/delete, paste events (with bracketed-paste support), Unicode
- Layout: Stack, frames, regions
- Rendering: cell buffer, borders, styles
- Widgets: ListWidget, TextAreaWidget, TextInputWidget (multi-line prompt with editing, arrow-key navigation, line splitting, and submit on Ctrl-D)
- UTF-8 and bracketed-paste support, SIGWINCH resize handling

## Quick Start

Add TerminalUI to your Swift project via Swift Package Manager:

```swift
.package(url: "https://github.com/nicholascross/TerminalUI.git", from: "0.1.0"),
```

Then add "TerminalUI" to your target dependencies and import it:

```swift
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
```

## Text Input Handling

The `TextInputWidget` supports:

- Multi-line text entry with Enter splitting lines.
- Character insertion and deletion (Backspace/Delete).
- Arrow-key navigation (←, →, ↑, ↓) across and within lines.
- Bracketed-paste support: pasted text (including multi-line) is inserted seamlessly.
- Submit buffer with Ctrl-D (`.submit`), which returns the full input and clears the widget.

## Example

Run the interactive example (press 'q' or Ctrl-C to quit):

```sh
swift run TerminalUIExample
```
