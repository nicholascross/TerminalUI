import TerminalUIComponents

@TerminalComponent
struct CommandMenu: TerminalView {
    @State private var query = ""
    @State private var selection: String?
    let items: [MenuItem]
    init(items: [MenuItem], initialSelection: Pane?) {
        self.items = items
        _selection = State(wrappedValue: (initialSelection ?? .topics).actionID)
    }

    var body: Element {
        Menu(id: "commands", title: "Layout commands", items: items, query: $query, selection: $selection)
    }
}
