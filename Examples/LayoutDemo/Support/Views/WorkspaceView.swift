import TerminalUI

@TerminalComponent
struct WorkspaceView: TerminalView {
    @State private var selected = "layout"
    let topics: [ListRow]
    let submit: (String) -> Void
    var body: some TerminalView {
        Column(spacing: 1) {
            Row(spacing: 1) {
                Component(TopicsView(topics: topics, selection: $selected), key: Pane.topics).width(.fixed(26))
                Component(InspectorView(selection: $selected), key: Pane.inspector)
            }
            Component(CommandPane(submit: submit), key: Pane.command).height(.fit(maximum: 7))
        }
    }
}
