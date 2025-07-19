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

Run the interactive example (press ‘q’ or Ctrl-C to quit).
The bottom input field is now rendered inside a bordered box (top border, content line, bottom border).
Use ↑/↓ to navigate the list, type and press Enter to add items, press Tab to switch focus, and see the blinking cursor inside the box.
Resize your terminal to see SIGWINCH handling:
```sh
swift run TerminalUIExample
```
