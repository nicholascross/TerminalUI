import TerminalUI

@main
@TerminalApplication
public struct ConsumerApplication {
    public var root: some TerminalView { Workspace() }
}

@TerminalComponent
public struct ApplicationControls: TerminalView {
    @ApplicationContext private var application

    public var body: some TerminalView {
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

    public var body: some TerminalView {
        Panel("Command") {
            TextEditor(id: "draft", text: $draft).onSubmit {
                submit(draft)
                draft = ""
            }
        }.height(.fit(maximum: 8))
    }
}

@TerminalComponent
public struct Workspace: TerminalView {
    @ApplicationContext private var application

    public var body: some TerminalView {
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
public func makeApplication() -> TerminalApp<Workspace> {
    TerminalApp(root: Workspace())
}

public struct BoundEditor: TerminalView {
    @Binding private var text: String
    public init(text: Binding<String>) {
        _text = text
    }

    public var body: some TerminalView {
        TextEditor(id: "bound", text: $text)
    }
}

public struct Framed<Content: TerminalView>: TerminalView {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some TerminalView { Panel("Generic") { content } }
}

public struct TypedLabel: TerminalView {
    public var body: Text { return Text("Explicitly typed body") }
}

public struct CompositionExamples: TerminalView {
    let expanded: Bool
    public var body: some TerminalView {
        Framed {
            TypedLabel()
            if expanded { Text("Expanded") } else { Text("Collapsed") }
            ForEach([1, 2, 3], id: \.self) { Text("Item \($0)").id($0) }
            for index in 0..<2 { Text("Position \(index)") }
        }
    }
}
