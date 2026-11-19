import TerminalUI

struct InspectorView: TerminalView {
    let selection: String
    var description: String {
        switch selection {
        case "components": "Struct components retain local state across parent refreshes. The workspace shares the selected topic with the inspector while the command keeps its own draft."
        case "composer": "The command panel grows with wrapped input up to seven rows, then the editor scrolls. Enter submits and clears this in-memory draft; Shift+Enter inserts a newline."
        default: "When the right border of Topics is marked, drag it to resize the sidebar. The inspector wraps at its new width."
        }
    }

    var body: some TerminalView {
        Panel("Inspector") {
            ScrollView(id: Pane.inspector.rawValue) {
                Column(spacing: 1) {
                    Paragraph(description)
                    for index in 1 ... 12 {
                        Paragraph(
                            "Example \(index): resize the terminal; the inspector wraps at its assigned width while the sidebar keeps its requested width.",
                        )
                    }
                }
            }
            .focusTarget(Pane.inspector)
        }
    }
}
