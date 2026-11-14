import TerminalUIComponents

struct HeaderView: TerminalView {
    var body: Element {
        Row {
            Text("TerminalUILayout").role(.heading)
            Spacer()
            Button("Quit", id: "quit")
        }
    }
}

struct NavigationView: TerminalView {
    let items: [MenuItem]
    let selection: String?
    @Binding var focusedItem: String?
    var body: Element {
        MenuBar(id: "navigation", items: items, selection: selection, focusedItem: $focusedItem)
    }
}
