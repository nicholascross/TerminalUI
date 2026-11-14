import TerminalUIComponents

@TerminalComponent
struct WorkspaceView: TerminalView {
    @State private var selected = "layout"
    let topics: [ListRow]
    let submit: (String) -> Void
    var body: Element {
        Column(spacing: 1) {
            Row(spacing: 1) {
                Component(TopicsView(topics: topics, selection: $selected), key: "topics").width(.fixed(26))
                Component(InspectorView(selection: $selected), key: "inspector")
            }
            Component(CommandPane(submit: submit), key: "command").height(.fit(maximum: 7))
        }
    }
}
