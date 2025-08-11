# TerminalUI

Minimal terminal UI toolkit in Swift.

<img width="810" height="530" alt="Example UI render" src="https://github.com/user-attachments/assets/5eb4e7d7-b437-451e-84c7-2fbdbf746ac8" />

## Features

- Terminal control: raw mode, cursor, styling, size detection
- Input parsing: character keys, arrow keys, backspace/delete, paste events (with bracketed-paste support), Unicode
- Layout: Stack, frames, regions
- Rendering: cell buffer, borders, styles
- Widgets:
  - **ListWidget**: vertical or horizontal list of selectable items with single- or multi-selection support. Configure `orientation` (.vertical/.horizontal), toggle items with Space when `allowsMultipleSelection` is enabled, and confirm selection(s) with Enter. Highlights the current item (▶ or brackets) and underlines selected items. Use the `onSelect` callback to receive selected indices and values.
  - **TextAreaWidget**: read-only or interactive multi-line text area with vertical scrolling (↑/↓), optional wrapping of overflowing lines (default: enabled), and optional title. Ideal for displaying details or logs.
  - **TextInputWidget**: single-line or multi-line input prompt with editing (insertion, deletion), arrow-key navigation (←/→/↑/↓), bracketed-paste support, and submit on Ctrl-D via the `onSubmit` callback.
- Ability to disable widgets via `isDisabled` property (widgets remain focusable but ignore events; border styling can indicate disabled state)
- Ability to hide widget borders via `isBorderHidden` property (widgets remain focusable and layout unchanged; border space reserved but not drawn)
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

// Build an interactive UI with a horizontal menu, a list, detail view, and text input
// Press Ctrl-D to submit input, or Ctrl-C to quit
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
menu.onSelect = { _, selections in
    if let sel = selections.first {
        details.text = "Menu selected: \(sel)"
    }
}

// Vertical list with multiple selection
let list = ListWidget(items: ["Apple", "Banana", "Cherry"], title: "Fruits")
list.allowsMultipleSelection = true
list.onSelect = { _, selections in
    details.text = selections.isEmpty
        ? "No fruits selected"
        : "Selected fruits: \(selections.joined(separator: ", "))"
}

let input = TextInputWidget(prompt: "> ", title: "Command")
input.onSubmit = { text in
    details.text = "You entered: \(text)"
}

let loop = UIEventLoop(terminal: terminal) {
    Stack(axis: .vertical, spacing: 0) {
        TextAreaWidget(
            text: " TerminalUI Demo ",
            isUserInteractive: false
        )
        .frame(height: 3)

        menu.frame(height: 3)

        Stack(axis: .horizontal, spacing: 1) {
            list.frame(width: 20)
            details
        }

        input.expanding(maxHeight: 8)
    }
}

try await loop.run()
```

## Text Input Handling

The `TextInputWidget` supports:

- Multi-line text entry with Enter splitting lines.
- Character insertion and deletion (Backspace/Delete).
- Arrow-key navigation (←, →, ↑, ↓) across and within lines.
- Bracketed-paste support: pasted text (including multi-line) is inserted seamlessly.
- Submit buffer with Ctrl-D (`.submit`), which returns the full input and clears the widget.

## Example

The `TerminalUIExample` demonstrates a horizontal menu, a vertical list with multiple-selection support, a detail view, and a text input prompt. Use ↑/↓ (or ←/→ for the menu), Space to toggle selection, Enter to confirm selection(s), and Ctrl-D to submit input. Press Ctrl-C to quit:

```sh
swift run TerminalUIExample
```

## Acknowledgements

This project has utilized generative AI tools in various aspects of its development, including coding assistance, testing, and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.
