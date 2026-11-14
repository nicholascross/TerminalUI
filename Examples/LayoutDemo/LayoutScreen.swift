import TerminalUIComponents

@TerminalComponent
struct LayoutScreen: TerminalView {
    @State private var model = LayoutViewModel()
    let currentPane: () -> String?
    let navigate: (String) -> Void
    let quit: () -> Void

    var body: Element {
        Column(spacing: 1) {
            Component(HeaderView(), key: "header")
            Component(NavigationView(items: model.navigationItems, selection: currentPane(),
                                     focusedItem: $model.barFocus), key: "navigation")
            Component(WorkspaceView(topics: model.topics, submit: { model.submit($0) }), key: "workspace")
            StatusBar(model.status)
            KeyHints("Alt+1–3: panes · Ctrl-P: menu · Enter: send · Shift+Enter: newline · Ctrl-C: quit")
        }
        .overlay(model.commandsOpen ? Component(CommandMenu(items: model.paneCommands, initialSelection: currentPane()), key: "commands") : nil)
        .onAction { action in
            switch action {
            case let .activated(id) where id.hasPrefix("pane."):
                guard let control = model.activatePane(id) else { return false }
                navigate(control)
            case .activated("commands"): model.openCommands()
            case .dismissRequested("commands"), .activated("commands.back"): model.dismissCommands()
            case .activated("quit"), .unhandledKey(.controlC): quit()
            default: return false
            }
            return true
        }
    }
}
