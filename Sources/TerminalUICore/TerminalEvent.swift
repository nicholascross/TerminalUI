/// Ordered input from the controlling terminal. Paste remains a keyboard data event.
public enum TerminalEvent: Equatable, Sendable {
    case key(KeyEvent)
    case mouse(MouseEvent)
}
