import TerminalUI

struct HeaderView: TerminalView {
    let quit: () -> Void

    var body: some TerminalView {
        Row {
            Text("TerminalUILayout").role(.heading)
            Spacer()
            Button("Quit").onActivate { quit() }
        }
    }
}
