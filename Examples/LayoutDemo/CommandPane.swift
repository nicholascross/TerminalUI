import TerminalUIComponents

@TerminalComponent
struct CommandPane: TerminalView {
    @State private var draft = ""
    let submit: (String) -> Void
    var body: Element {
        Panel("Command") {
            TextEditor(id: "command", text: $draft, placeholder: "Type a multiline command…")
                .onSubmit { submit(draft); draft = "" }
        }
    }
}
