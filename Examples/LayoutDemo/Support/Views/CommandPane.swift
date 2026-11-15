import TerminalUI

@TerminalComponent
struct CommandPane: TerminalView {
    @State private var draft = ""
    let submit: (String) -> Void

    var body: some TerminalView {
        Panel("Command") {
            TextEditor(id: Pane.command.rawValue, text: $draft, placeholder: "Type a multiline command…")
                .focusTarget(Pane.command)
                .onSubmit {
                    submit(draft)
                    draft = ""
                }
        }
    }
}
