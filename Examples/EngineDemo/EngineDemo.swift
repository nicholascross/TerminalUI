import Foundation
import TerminalUIEngine

/// A small raw-engine application: values live here; the host retains focus and scrolling by control ID.
@MainActor
final class EngineApplication: TerminalApplication {
    let host: TerminalHost
    var selection = "layout"
    var note = "Edit this in-memory note."
    let topics = [
        ListRow(id: "layout", title: "Layout"), ListRow(id: "input", title: "Input"),
        ListRow(id: "state", title: "State"),
    ]

    init(host: TerminalHost) { self.host = host }

    func view() -> Element {
        .column(
            spacing: 1,
            [
                .text("TerminalUI Engine").role(.heading),
                .row(
                    spacing: 1,
                    [
                        .panel(title: "Topics", content: .list(id: "topics", rows: topics, selection: selection))
                            .width(.fixed(18)),
                        .panel(title: "Details", content: .scrollView(id: "details", content: .paragraph(description)))
                            .width(.fill()),
                    ]
                ).height(.fill()),
                .textField(id: "note", value: note),
                .button("Quit", id: "quit"),
                .statusBar("Tab focus · ↑/↓ select · Ctrl-C quit"),
            ])
    }

    private var description: String {
        switch selection {
        case "input": "TerminalHost decodes input, routes it to the focused control and sends application actions to handle(_:)."
        case "state":
            "The application applies text and selection changes to its own values. Stable control IDs preserve engine-owned focus, caret and viewport state."
        default: "Compose raw Element values into rows, columns and panels. The engine measures and renders the tree for the available terminal size."
        }
    }

    func handle(_ action: UIAction) {
        switch action {
        case .selectionChanged("topics", let id): selection = id
        case .textChanged("note", let value): note = value
        case .activated("quit"), .unhandledKey(.controlC): host.stop()
        default: break
        }
    }
}

@main
struct EngineDemo {
    @MainActor static func main() async throws {
        let arguments = CommandLine.arguments
        let host = TerminalHost(configuration: .init(mouseEnabled: !arguments.contains("--no-mouse")), theme: .nord())
        let app = EngineApplication(host: host)
        if arguments.contains("--preview") {
            for line in host.preview(LegacyApplicationPresentation(app)) { print(line) }
        } else {
            try await host.run(app)
        }
    }
}
