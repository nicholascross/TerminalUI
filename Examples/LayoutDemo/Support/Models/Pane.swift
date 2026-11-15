/// Destinations shared by navigation commands, component keys and scoped focus requests.
public enum Pane: String, CaseIterable, Sendable {
    case topics, inspector, command

    public var title: String {
        switch self {
        case .topics: "Topics"
        case .inspector: "Inspector"
        case .command: "Command"
        }
    }

    var shortcut: Character {
        switch self {
        case .topics: "1"
        case .inspector: "2"
        case .command: "3"
        }
    }

    var actionID: String {
        "pane." + rawValue
    }

    init?(actionID: String) {
        guard let pane = Self.allCases.first(where: { $0.actionID == actionID }) else { return nil }
        self = pane
    }
}
