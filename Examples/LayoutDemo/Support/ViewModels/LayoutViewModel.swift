import TerminalUI

/// Shared presentation state and commands. The screen stores this value in one mounted @State slot.
public struct LayoutViewModel: Equatable, Sendable {
    public var status = "Ready"
    public var commandsOpen = false

    public init() {}

    public mutating func submit(_ command: String) {
        status = "Submitted \(command.count) characters"
    }

    public mutating func openCommands() {
        commandsOpen = true
    }

    public mutating func dismissCommands() {
        commandsOpen = false
    }

    public mutating func didFocus(_ pane: Pane) {
        status = "Focus: \(pane.title)"
    }

    public var topics: [ListRow] {
        [ListRow(id: "layout", title: "Negotiated layout"),
         ListRow(id: "components", title: "Stateful components"),
         ListRow(id: "composer", title: "Growing composer")]
    }

    public func contextualHints(for focusedPane: Pane?) -> String {
        if commandsOpen { return "Type to filter · ↓ results · Enter open · Esc return" }
        switch focusedPane {
        case .topics: return "↑/↓ select a topic · Tab next pane"
        case .inspector: return "↑/↓ scroll · PgUp/PgDn page · Tab next pane"
        case .command: return "Enter send · Shift+Enter newline · paste inserts text"
        case nil: return "←/→ choose · Enter activate · Tab next control"
        }
    }
}
