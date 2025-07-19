import Foundation
import Darwin.C

/// Low-level control over terminal: raw mode, cursor control, styling, and size.
public enum Terminal {
    /// Called on terminal resize with new (rows, cols).
    public static var onResize: ((Int, Int) -> Void)?

    /// Enable raw mode (disable canonical input and echo).
    public static func enableRawMode() throws {
        var orig = termios()
        guard tcgetattr(STDIN_FILENO, &orig) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        _originalTermios = orig
        var raw = orig
        raw.c_lflag &= ~(UInt(ECHO | ICANON | IEXTEN | ISIG))
        raw.c_iflag &= ~(UInt(IXON | ICRNL))
        raw.c_cflag |= UInt(CS8)
        raw.c_oflag &= ~(UInt(OPOST))
        raw.c_cc.6 = 1 // VMIN
        raw.c_cc.5 = 0 // VTIME
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        _rawModeEnabled = true
        // Install SIGWINCH handler for window resize events
        signal(SIGWINCH, _resizeHandler)
    }

    /// Disable raw mode and restore terminal settings.
    public static func disableRawMode() throws {
        guard _rawModeEnabled, var orig = _originalTermios else { return }
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        _rawModeEnabled = false
    }

    /// Clear the entire screen.
    public static func clearScreen() {
        print("\u{1B}[2J", terminator: "")
        moveCursor(row: 1, col: 1)
    }

    /// Move the cursor to the specified row and column (1-based).
    public static func moveCursor(row: Int, col: Int) {
        print("\u{1B}[\(row);\(col)H", terminator: "")
    }

    /// Hide the cursor.
    public static func hideCursor() {
        print("\u{1B}[?25l", terminator: "")
    }

    /// Show the cursor.
    public static func showCursor() {
        print("\u{1B}[?25h", terminator: "")
    }

    /// Apply the given style.
    public static func setStyle(_ style: Style) {
        var codes: [Int] = []
        if style.contains(.bold) { codes.append(1) }
        if style.contains(.underline) { codes.append(4) }
        if style.contains(.reverse) { codes.append(7) }
        let seq = codes.map(String.init).joined(separator: ";")
        print("\u{1B}[\(seq)m", terminator: "")
    }

    /// Reset all styles.
    public static func resetStyle() {
        print("\u{1B}[0m", terminator: "")
    }

    /// Query the current terminal size (rows, columns).
    public static func getTerminalSize() -> (rows: Int, cols: Int) {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) == 0 {
            return (rows: Int(ws.ws_row), cols: Int(ws.ws_col))
        }
        return (rows: 24, cols: 80)
    }
    // Stored original terminal state
    private static var _originalTermios: termios?
    private static var _rawModeEnabled = false

    // C signal handler for SIGWINCH
    private static let _resizeHandler: @convention(c) (Int32) -> Void = { _ in
        if let cb = Terminal.onResize {
            let size = Terminal.getTerminalSize()
            cb(size.rows, size.cols)
        }
    }
}

/// Styling options for text output.
public struct Style: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let bold      = Style(rawValue: 1 << 0)
    public static let underline = Style(rawValue: 1 << 1)
    public static let reverse   = Style(rawValue: 1 << 2)
    // Add color options as needed.
}
