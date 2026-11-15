import TerminalUIComponents

struct TopicsView: TerminalView {
    let topics: [ListRow]
    @Binding var selection: String
    var body: Element {
        Panel("Topics") { List(id: Pane.topics.rawValue, rows: topics, selection: $selection) }
    }
}
