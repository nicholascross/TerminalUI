import TerminalUI

struct TopicsView: TerminalView {
    let topics: [ListRow]
    @Binding var selection: String
    var body: some TerminalView {
        Panel("Topics") { List(id: Pane.topics.rawValue, rows: topics, selection: $selection) }
    }
}
