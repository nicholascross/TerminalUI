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
