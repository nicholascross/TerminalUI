# TerminalUI

Minimal terminal UI toolkit in Swift.

## Modules

- **Terminal.swift**: raw mode, cursor control, styling, and terminal size.
- **Input.swift**: decode keypresses into `InputEvent`.
- **Layout.swift**: manage screen regions (`Region`) and layout calculations.
- **Renderer.swift**: cell buffer, rendering, and border‑drawing API.
- **UIEventLoop.swift**: main event loop to process input and update the UI.

## Build

```sh
mkdir -p .build/tmp .build/home
TMPDIR="$(pwd)/.build/tmp" HOME="$(pwd)/.build/home" swift build --disable-sandbox
```

## Usage

See module documentation in source files for examples.

## Example

Run the interactive example (press 'q' or Ctrl-C to quit). The interface now consists of:

- A fixed-height header banner at the top.
- A two-pane split: left pane shows a selectable list (fixed width), and right pane shows a scrollable text area.
- A fixed-height input box at the bottom.

Borders are drawn around each region with proper joins and spacing. Use:

- ↑/↓ to scroll the header or text area and to move selection in the list.
- Type and press Enter in the input box to append items to the list.
- Tab to cycle focus through header, list, text area, and input.
- Resize your terminal to see SIGWINCH (resize) handling.

```sh
swift run TerminalUIExample
```
