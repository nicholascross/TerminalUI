# TerminalUI

Minimal terminal UI toolkit in Swift.

## Modules

- **Terminal.swift**: raw mode, cursor control, styling, and terminal size.
- **Input.swift**: decode keypresses into `InputEvent`.
- **Layout.swift**: manage screen regions and layout calculations.
- **Renderer.swift**: screen buffer and rendering functions.
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
Use ↑/↓ to navigate the list, type and press Enter (Return) to add items (when input is focused), and press Tab to switch focus between list and input widgets.
Resize your terminal to see SIGWINCH handling:
```sh
swift run TerminalUIExample
```
