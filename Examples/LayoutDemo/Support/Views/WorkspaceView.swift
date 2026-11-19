import TerminalUI

@TerminalComponent
struct WorkspaceView: TerminalView {
    @State private var selected = "layout"
    let topics: [ListRow]
    let submit: (String) -> Void

    var body: some TerminalView {
        Column(spacing: 1) {
            Row(spacing: 1) {
                TopicsView(topics: topics, selection: $selected)
                    .id(Pane.topics)
                    .resizable(id: "topics-pane", edge: .trailing, minimum: 22, maximum: 40, preferredSize: 26)
                InspectorView(selection: selected)
                    .id(Pane.inspector)
                    .layoutSizing(width: .flexible(minimum: 24))
            }
            CommandPane(submit: submit).id(Pane.command).height(.fit(maximum: 7))
        }
    }
}
