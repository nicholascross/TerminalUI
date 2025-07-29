import Foundation
import Darwin.C

/// A stream for writing text to stdout.
private struct StdoutStream: TextOutputStream {
    func write(_ string: String) {
        fputs(string, stdout)
    }
}

/// Low-level control over terminal: raw mode, cursor control, styling, and size.
/// Global terminal control and styling utilities.
public final class Terminal {
    /// Called internally to dispatch resize signals to the active terminal instance.
    private static weak var activeResizeListener: Terminal?

    /// Create a new Terminal instance for controlling terminal I/O.
    public init() {}
    /// The output stream to use for terminal control sequences and text.
    public var output: TextOutputStream = StdoutStream()
    /// Called on terminal resize with new (rows, cols).
    public var onResize: ((Int, Int) -> Void)?

    /// Enable raw mode (disable canonical input and echo).
    public func enableRawMode() throws {
        var orig = termios()
        guard tcgetattr(STDIN_FILENO, &orig) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        _originalTermios = orig
        var raw = orig
        raw.c_lflag &= ~(UInt(ECHO | ICANON | IEXTEN | ISIG))
        // Disable flow control, carriage return-to-newline translation, and other input processing
        raw.c_iflag &= ~(UInt(BRKINT | ICRNL | INPCK | ISTRIP | IXON))
        raw.c_cflag |= UInt(CS8)
        raw.c_oflag &= ~(UInt(OPOST))
        raw.c_cc.6 = 1 // VMIN
        raw.c_cc.5 = 0 // VTIME
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        _rawModeEnabled = true
        // Install SIGWINCH handler for window resize events
        Terminal.activeResizeListener = self
        signal(SIGWINCH, Terminal._resizeHandler)
        // Enable bracketed paste mode
        output.write("\u{1B}[?2004h")
        fflush(stdout)
    }

    /// Disable raw mode and restore terminal settings.
    public func disableRawMode() throws {
        guard _rawModeEnabled, var orig = _originalTermios else { return }
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
        }
        // Disable bracketed paste mode
        output.write("\u{1B}[?2004l")
        fflush(stdout)
        _rawModeEnabled = false
    }

    /// Clear the entire screen.
    public func clearScreen() {
        output.write("\u{1B}[2J")
        moveCursor(row: 1, col: 1)
    }

    /// Move the cursor to the specified row and column (1-based).
    public func moveCursor(row: Int, col: Int) {
        output.write("\u{1B}[\(row);\(col)H")
    }

    /// Hide the cursor.
    public func hideCursor() {
        output.write("\u{1B}[?25l")
    }

    /// Show the cursor.
    public func showCursor() {
        output.write("\u{1B}[?25h")
    }

    /// Apply the given style.
    public func setStyle(_ style: Style) {
        var codes: [Int] = []
        if style.contains(.bold) { codes.append(1) }
        if style.contains(.underline) { codes.append(4) }
        if style.contains(.reverse) { codes.append(7) }
        let seq = codes.map(String.init).joined(separator: ";")
        output.write("\u{1B}[\(seq)m")
    }

    /// Reset all styles.
    public func resetStyle() {
        output.write("\u{1B}[0m")
    }

    /// Query the current terminal size (rows, columns).
    public func getTerminalSize() -> (rows: Int, cols: Int) {
        var windowSize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &windowSize) == 0 {
            return (rows: Int(windowSize.ws_row), cols: Int(windowSize.ws_col))
        }
        return (rows: 24, cols: 80)
    }
    // Stored original terminal state
    private var _originalTermios: termios?
    private var _rawModeEnabled = false

/// C signal handler for SIGWINCH.
private static let _resizeHandler: @convention(c) (Int32) -> Void = { _ in
    if let listener = Terminal.activeResizeListener,
       let callback = listener.onResize {
        let size = listener.getTerminalSize()
        callback(size.rows, size.cols)
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
