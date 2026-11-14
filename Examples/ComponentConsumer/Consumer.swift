import TerminalUIComponents

@main
@TerminalApplication
public struct ConsumerApplication {
    public var root: some TerminalView { Workspace() }
}

@TerminalComponent
public struct ApplicationControls: TerminalView {
    @ApplicationContext private var application

    public var body: Element {
        Button("Quit", id: "quit").onActivate { application.stop() }
    }
}

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

@TerminalComponent
public struct Workspace: TerminalView {
    @ApplicationContext private var application

    public var body: Element {
        Column {
            Text("Workspace")
            CommandPane(submit: { _ in })
            Component(CommandPane(submit: { _ in }), key: "second")
            ApplicationControls()
            StatusBar("Tab: focus · Enter: submit · Shift+Enter: newline · Ctrl-C: quit")
        }
        .onAction { action in
            guard case .unhandledKey(.controlC) = action else { return false }
            application.stop()
            return true
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
