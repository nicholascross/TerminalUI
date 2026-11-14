import TerminalUIComponents

@TerminalComponent
struct CommandMenu: TerminalView {
    @State private var query = ""
    @State private var selection: String?
    let items: [MenuItem]
    init(items: [MenuItem], initialSelection: String?) {
        self.items = items
        _selection = State(wrappedValue: initialSelection ?? "pane.topics")
    }

    var body: Element {
        Menu(id: "commands", title: "Layout commands", items: items, query: $query, selection: $selection)
    }
}
