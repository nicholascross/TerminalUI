import TerminalUI

struct NavigationView: TerminalView {
    let items: [MenuItem]
    let selection: String?
    @Binding var focusedItem: String?
    var body: some TerminalView {
        MenuBar(id: "navigation", items: items, selection: selection, focusedItem: $focusedItem)
    }
}
