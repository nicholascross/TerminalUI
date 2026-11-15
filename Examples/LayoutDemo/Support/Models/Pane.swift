import TerminalUI

/// Destinations shared by navigation commands, view IDs and scoped focus requests.
public enum Pane: String, CaseIterable, Sendable, MenuItemDefinition {
    case topics, inspector, command

    public var title: String {
        switch self {
        case .topics: "Topics"
        case .inspector: "Inspector"
        case .command: "Command"
        }
    }

    public var id: String {
        "pane." + rawValue
    }
}
