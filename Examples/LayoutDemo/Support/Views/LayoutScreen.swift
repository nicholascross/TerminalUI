import TerminalUI

@TerminalComponent
public struct LayoutScreen: TerminalView {
    @State private var model = LayoutViewModel()
    @State private var previousTheme: Theme?
    @ApplicationContext private var application

    public init() {}

    private var focusedPane: Pane? { application.focusedValue(of: Pane.self) }

    public var body: some TerminalView {
        Column(spacing: 1) {
            HeaderView(
                themeTitle: previousTheme == nil ? "Light theme" : "Restore theme",
                changeTheme: toggleTheme,
                quit: { application.stop() }
            )
            Row(spacing: 1) {
                MenuBar(id: "navigation", items: Pane.allCases, activeItem: focusedPane)
                    .id("navigation")
                Button("Commands")
                    .onActivate { model.openCommands() }
                    .keyboardShortcut(.controlP)
            }
            WorkspaceView(topics: model.topics, submit: { model.submit($0) })
                .id("workspace")
            StatusBar(model.status)
            Column {
                Text(model.contextualHints(for: focusedPane)).role(.secondary)
                Text("Alt+1–3 panes · Ctrl-P menu · Alt+T theme · Ctrl-C quit").role(.secondary)
            }
        }
        .overlay {
            if model.commandsOpen {
                Menu(
                    id: "commands", title: "Layout commands",
                    items: Pane.allCases, initialSelection: focusedPane,
                    itemTitle: { "Focus \($0.title)" }
                )
                .onActivate { model.dismissCommands() }
                .onDismiss { model.dismissCommands() }
            }
        }
        .onFocusChange(of: Pane.self) { pane in
            if let pane { model.didFocus(pane) }
        }
        .onAction(handle)
    }

    private func toggleTheme() {
        if let previousTheme {
            application.theme = previousTheme
            self.previousTheme = nil
        } else {
            previousTheme = application.theme
            application.theme = .light
        }
    }

    private func handle(_ action: UIAction) -> Bool {
        guard case .unhandledKey(.controlC) = action else { return false }
        application.stop()
        return true
    }
}
