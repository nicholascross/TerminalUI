public enum UIAction: Equatable, Sendable {
    case activated(String), textChanged(String, String), selectionChanged(String, String)
    case dismissRequested(String), unhandledKey(KeyEvent), resized(TerminalSize), pasteTruncated
}
