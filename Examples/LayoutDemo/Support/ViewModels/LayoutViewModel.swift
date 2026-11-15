import TerminalUI

/// Shared presentation state and commands. The screen stores this value in one mounted @State slot.
public struct LayoutViewModel: Equatable, Sendable {
    public var status = "Ready"
    public var barFocus: String? = Pane.topics.id
    public var focusedPane: Pane?
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

    public mutating func didNavigate(to pane: Pane) {
        status = "Focus: \(pane.title)"
    }

    public var topics: [ListRow] {
        [ListRow(id: "layout", title: "Negotiated layout"),
         ListRow(id: "components", title: "Stateful components"),
         ListRow(id: "composer", title: "Growing composer")]
    }

    public var paneCommands: [MenuItem] {
        Pane.allCases.map { pane in
            MenuItem(id: pane.id, title: "Focus " + pane.title, shortcut: pane.shortcut)
        }
    }

    public var navigationItems: [MenuItem] {
        Pane.allCases.map { pane in
            MenuItem(id: pane.id, title: pane.title, shortcut: pane.shortcut,
                     globalShortcuts: [.altCharacter(pane.shortcut), .controlCharacter(pane.shortcut)])
        } + [MenuItem(id: "commands", title: "Commands", globalShortcuts: [.controlP])]
    }
}
