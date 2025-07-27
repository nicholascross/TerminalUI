import Foundation

/// A discrete key or control event read from the terminal.
public enum InputEvent: Equatable, Hashable, Sendable {
    /// A Unicode character that was typed.
    case char(Character)
    /// The Enter, Backspace/Delete, or Tab keys.
    case enter, backspace, tab
    /// A “submit” control (e.g. ^D in raw mode).
    case submit
    /// Arrow keys.
    case upArrow, downArrow, leftArrow, rightArrow
    /// ^C (only delivered if ISIG is off).
    case ctrlC
    /// End‐of‐file (pipe closed or ^D in cooked mode).
    case eof
    /// Bracketed‐paste start/end markers.
    case pasteStart, pasteEnd
    /// Unrecognized or invalid sequence.
    case unknown
}
