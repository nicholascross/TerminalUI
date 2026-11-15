import TerminalUI

struct HeaderView: TerminalView {
    var body: some TerminalView {
        Row {
            Text("TerminalUILayout").role(.heading)
            Spacer()
            Button("Quit", id: "quit")
        }
    }
}
