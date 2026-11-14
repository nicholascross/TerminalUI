import TerminalUIComponents

struct TopicsView: TerminalView {
    let topics: [ListRow]
    @Binding var selection: String
    var body: Element {
        Panel("Topics") { List(id: "topics", rows: topics, selection: $selection) }
    }
}

struct InspectorView: TerminalView {
    @Binding var selection: String
    var description: String {
        switch selection {
        case "components": "Struct components retain local state across parent refreshes. Bindings connect the topics and inspector while the command keeps its own draft."
        case "composer": "The command panel grows with wrapped input up to seven rows, then the editor scrolls. Enter submits and clears this in-memory draft; Shift+Enter inserts a newline."
        default: "The header and status bar request their content height. The workspace accepts the remaining height. Panels pass their children's sizing preferences through their borders."
        }
    }

    var body: Element {
        Panel("Inspector") {
            ScrollView(id: "inspector") {
                Column(spacing: 1) {
                    Paragraph(description)
                    for index in 1 ... 12 {
                        Paragraph(
                            "Example \(index): resize the terminal; the inspector wraps at its assigned width while the sidebar keeps its requested width.",
                        )
                    }
                }
            }
        }
    }
}
