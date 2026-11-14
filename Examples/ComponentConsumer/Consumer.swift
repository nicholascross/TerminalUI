import TerminalUIComponents

@TerminalComponent
public struct CommandPane: TerminalView {
    @State private var draft = ""
    private let submit: (String) -> Void
    public init(submit: @escaping (String) -> Void) {
        self.submit = submit
    }

    public var body: Element {
        Panel("Command") {
            TextEditor(id: "draft", text: $draft).onSubmit { submit(draft); draft = "" }
        }.height(.fit(maximum: 8))
    }
}

public struct Workspace: TerminalView {
    public var body: Element {
        Column {
            Text("Workspace")
            CommandPane(submit: { _ in })
            Component(CommandPane(submit: { _ in }), key: "second")
        }
    }
}

@MainActor
public func makeApplication() -> ComponentApplication {
    ComponentApplication(root: Workspace())
}

public struct BoundEditor: TerminalView {
    @Binding private var text: String
    public init(text: Binding<String>) {
        _text = text
    }

    public var body: Element {
        TextEditor(id: "bound", text: $text)
    }
}
