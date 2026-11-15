/// Errors acquiring or communicating with a terminal.
public enum TerminalError: Error, Equatable, Sendable {
    case unsupportedTerminal
    case noControllingTerminal
    case invalidSize
    case sessionAlreadyActive
    case outputUnavailable
    case systemCall(String, Int32)
}
