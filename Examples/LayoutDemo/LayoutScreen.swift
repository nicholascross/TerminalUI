import TerminalUIComponents

@TerminalComponent
public struct LayoutScreen: TerminalView {
    @State private var model = LayoutViewModel()
    @ApplicationContext private var application

    public init() {}

    private var navigation: LayoutNavigation { LayoutNavigation(application: application) }

    public var body: Element {
        Column(spacing: 1) {
            Component(HeaderView(), key: "header")
            Component(NavigationView(items: model.navigationItems, selection: model.focusedPane?.actionID,
                                     focusedItem: $model.barFocus), key: "navigation")
            Component(WorkspaceView(topics: model.topics, submit: { model.submit($0) }), key: "workspace")
            StatusBar(model.status)
            KeyHints("Alt+1–3: panes · Ctrl-P: menu · Enter: send · Shift+Enter: newline · Ctrl-C: quit")
        }
        .overlay(model.commandsOpen ? Component(CommandMenu(items: model.paneCommands, initialSelection: model.focusedPane), key: "commands") : nil)
        .onFocusChange { model.focusedPane = navigation.pane(for: $0) }
        .onAction(handle)
    }

    private func handle(_ action: UIAction) -> Bool {
        if case let .activated(id) = action, let pane = Pane(actionID: id) {
            model.dismissCommands()
            if navigation.focus(pane) { model.didNavigate(to: pane) }
            return true
        }
        switch action {
        case .activated("commands"): model.openCommands()
        case .dismissRequested("commands"), .activated("commands.back"): model.dismissCommands()
        case .activated("quit"), .unhandledKey(.controlC): navigation.stop()
        default: return false
        }
        return true
    }
}
