import TerminalUIComponents

/// Shared presentation state and commands. The screen stores this value in one mounted @State slot.
public struct LayoutViewModel: Equatable, Sendable {
    public var status = "Ready"
    public var barFocus: String? = "pane.topics"
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

    public mutating func activatePane(_ id: String) -> String? {
        guard ["pane.topics", "pane.inspector", "pane.command"].contains(id) else { return nil }
        let control = String(id.dropFirst("pane.".count))
        commandsOpen = false
        status = "Focus: \(control.capitalized)"
        return control
    }

    public var topics: [ListRow] {
        [ListRow(id: "layout", title: "Negotiated layout"),
         ListRow(id: "components", title: "Stateful components"),
         ListRow(id: "composer", title: "Growing composer")]
    }

    public var paneCommands: [MenuItem] {
        [MenuItem(id: "pane.topics", title: "Focus Topics", shortcut: "1"),
         MenuItem(id: "pane.inspector", title: "Focus Inspector", shortcut: "2"),
         MenuItem(id: "pane.command", title: "Focus Command", shortcut: "3")]
    }

    public var navigationItems: [MenuItem] {
        zip(paneCommands, ["Topics", "Inspector", "Command"]).map { command, title in
            MenuItem(id: command.id, title: title, shortcut: command.shortcut,
                     globalShortcuts: command.shortcut.map { [.altCharacter($0), .controlCharacter($0)] } ?? [])
        } + [MenuItem(id: "commands", title: "Commands", globalShortcuts: [.controlP])]
    }
}
