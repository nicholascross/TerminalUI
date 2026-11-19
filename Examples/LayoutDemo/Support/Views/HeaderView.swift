import TerminalUI

struct HeaderView: TerminalView {
    let themeTitle: String
    let changeTheme: () -> Void
    let quit: () -> Void

    var body: some TerminalView {
        Row {
            Text("TerminalUILayout").role(.heading)
            Spacer()
            Button(themeTitle, id: "theme")
                .onActivate { changeTheme() }
                .keyboardShortcut(.altCharacter("t"))
            Button("Quit").onActivate { quit() }
        }
    }
}
