import Foundation
import TerminalUILayout

@main
struct LayoutDemo {
    @MainActor
    static func main() async throws {
        let app = LayoutApplication(mouseEnabled: !CommandLine.arguments.contains("--no-mouse"))
        if CommandLine.arguments.contains("--preview") {
            for line in UIEngine(theme: .dusk()).render(app.view(), width: 80, height: 24) { print(line) }
        } else {
            try await app.host.run(app)
        }
    }
}

@MainActor
final class LayoutApplication: TerminalApplication {
    let host: TerminalHost
    var selected = "layout"
    var draft = ""
    var status = "Ready"
    var barFocus: String? = "pane.topics"
    var commandsOpen = false
    var commandQuery = ""
    var commandSelection: String? = "pane.topics"
    let topics = [
        ListRow(id: "layout", title: "Negotiated layout"),
        ListRow(id: "components", title: "Existing components"),
        ListRow(id: "composer", title: "Growing composer"),
    ]

    init(mouseEnabled: Bool = true) {
        host = TerminalHost(configuration: TerminalConfiguration(mouseEnabled: mouseEnabled), theme: .dusk())
    }

    var paneCommands: [MenuItem] {
        [MenuItem(id: "pane.topics", title: "Focus Topics", shortcut: "1"),
         MenuItem(id: "pane.inspector", title: "Focus Inspector", shortcut: "2"),
         MenuItem(id: "pane.command", title: "Focus Command", shortcut: "3")]
    }

    var navigationItems: [MenuItem] {
        zip(paneCommands, ["Topics", "Inspector", "Command"]).map { command, title in
            MenuItem(id: command.id, title: title, shortcut: command.shortcut,
                     globalShortcuts: command.shortcut.map { [.altCharacter($0), .controlCharacter($0)] } ?? [])
        } + [MenuItem(id: "commands", title: "Commands", globalShortcuts: [.controlP])]
    }

    var currentPane: String? {
        switch host.focusedID {
        case "topics": "pane.topics"
        case "inspector": "pane.inspector"
        case "command": "pane.command"
        default: nil
        }
    }

    func view() -> Element {
        Column(spacing: 1) {
            Row {
                Text("TerminalUILayout").role(.heading)
                Spacer()
                Button("Quit", id: "quit")
            }

            MenuBar(id: "navigation", items: navigationItems, selection: currentPane, focusedItem: barFocus)

            Row(spacing: 1) {
                Panel("Topics") {
                    List(id: "topics", rows: topics, selection: selected)
                }
                .width(.fixed(26))

                Panel("Inspector") {
                    ScrollView(id: "inspector") {
                        Column(spacing: 1) {
                            Paragraph(description)
                            for index in 1...12 {
                                Paragraph("Example \(index): resize the terminal; the inspector wraps at its assigned width while the sidebar keeps its requested width.")
                            }
                        }
                    }
                }
            }

            Panel("Command") {
                TextEditor(id: "command", value: draft, placeholder: "Type a multiline command…")
                    .onSubmit("submit")
            }
            .height(.fit(maximum: 7))

            StatusBar(status)
            KeyHints("Alt+1–3: panes · Ctrl-P: menu · Enter: send · Shift+Enter: newline · Ctrl-C: quit")
        }
        .overlay(commandsOpen ? Menu(id: "commands", title: "Layout commands", items: paneCommands,
                                     query: commandQuery, selection: commandSelection) : nil)
    }

    var description: String {
        switch selected {
        case "components": "These are the existing list, scroll view, editor and button. Focus, pointer input and scrolling use the same engine as array-based layouts."
        case "composer": "The command panel grows with wrapped input up to seven rows, then the editor scrolls. Enter submits and clears this in-memory draft; Shift+Enter inserts a newline."
        default: "The header and status bar request their content height. The workspace accepts the remaining height. Panels pass their children's sizing preferences through their borders."
        }
    }

    func handle(_ action: UIAction) {
        switch action {
        case let .activated(id) where id.hasPrefix("pane."):
            commandsOpen = false
            let control = String(id.dropFirst("pane.".count))
            if host.focus(control, in: view()) {
                status = "Focus: \(control == "command" ? "Command" : control.capitalized)"
            }
        case .activated("commands"):
            commandsOpen = true
            commandQuery = ""
            commandSelection = currentPane ?? "pane.topics"
        case .dismissRequested("commands"), .activated("commands.back"): commandsOpen = false
        case let .selectionChanged("navigation", id): barFocus = id
        case let .textChanged("commands.search", value): commandQuery = value
        case let .selectionChanged("commands.items", id): commandSelection = id
        case let .selectionChanged("topics", id): selected = id
        case let .textChanged("command", value): draft = value
        case .activated("submit"):
            status = "Submitted \(draft.count) characters"
            draft = ""
        case .activated("quit"), .unhandledKey(.controlC): host.stop()
        default: break
        }
    }
}
