import TerminalUICore

/// Coordinates keyboard policy through injected focus, editing and collection services.
package struct KeyboardRouter {
    private let states: WidgetStateStore
    private let focus: FocusManager
    private let tree: ElementTree
    private let editor: EditorInteraction
    private let collection: CollectionInteraction
    private let shortcuts: MenuShortcutRouter

    package init(
        states: WidgetStateStore,
        focus: FocusManager,
        tree: ElementTree,
        editor: EditorInteraction,
        collection: CollectionInteraction,
        shortcuts: MenuShortcutRouter,
    ) {
        self.states = states
        self.focus = focus
        self.tree = tree
        self.editor = editor
        self.collection = collection
        self.shortcuts = shortcuts
    }

    package func handle(_ key: KeyEvent, in root: Element, theme: Theme) -> InteractionOutcome {
        let previousFocus = focus.focusedID
        focus.synchronize(root)
        let result = handleKey(key, in: root, theme: theme)
        if result == .repaint, previousFocus == focus.focusedID, let id = focus.focusedID {
            return .viewport(id)
        }
        return .rebuild(result.action)
    }

    private func handleKey(_ key: KeyEvent, in root: Element, theme: Theme) -> UIEventResult {
        let active = tree.modal(root) ?? root
        if let result = shortcuts.route(key, in: root, active: active) { return result }
        let controls = tree.focusables(active)
        guard !controls.isEmpty else {
            if case .escape = key, case let .dialog(id, _, _) = active.kind { return .rebuild(action: .dismissRequested(id)) }
            focus.setFocus(nil)
            return .rebuild(action: .unhandledKey(key))
        }
        if !controls.contains(where: { $0.0 == focus.focusedID }) { focus.setFocus(controls[0].0) }
        if key == .tab || key == .backTab {
            let index = controls.firstIndex(where: { $0.0 == focus.focusedID }) ?? 0
            focus.setFocus(controls[(index + (key == .tab ? 1 : controls.count - 1)) % controls.count].0)
            return .rebuild(action: nil)
        }
        if key == .escape, case let .dialog(id, _, _) = active.kind { return .rebuild(action: .dismissRequested(id)) }
        guard let control = controls.first(where: { $0.0 == focus.focusedID })?.1 else { return .rebuild(action: nil) }
        if key == .down, let resultsID = control.menuResultsID {
            focus.setFocus(resultsID)
            return .rebuild(action: nil)
        }
        if let binding = control.keyActions.first(where: { $0.key == key }) {
            if active.menuShortcutItems.contains(where: { $0.id == binding.actionID && $0.unavailableReason != nil }) {
                return .rebuild(action: nil)
            }
            return .rebuild(action: .activated(binding.actionID))
        }
        return handleControl(key, control: control, theme: theme)
    }

    private func handleControl(_ key: KeyEvent, control: Element, theme: Theme) -> UIEventResult {
        switch control.kind {
        case let .button(_, id):
            if key == .enter || key == .character(" ") { return .rebuild(action: .activated(id)) }
        case let .field(id, value, _, multiline):
            if key == .enter, let submitID = control.submitID { return .rebuild(action: .activated(submitID)) }
            return editor.handle(key, id: id, value: value, multiline: multiline)
        case .list, .table:
            return collection.handle(key, control: control)
        case let .custom(widget):
            switch widget.respond(to: key, context: WidgetEventContext(focused: true, theme: theme)) {
            case .unhandled: return .rebuild(action: .unhandledKey(key))
            case .consumed: return .rebuild(action: nil)
            case let .action(action): return .rebuild(action: action)
            }
        case let .scroll(id, _):
            let stateID = "scroll:" + id
            let step = max(1, states[stateID].viewport.height ?? 1)
            switch key {
            case .up: states[stateID].viewport.offset = max(0, (states[stateID].viewport.offset ?? 0) - 1)
            case .down: states[stateID].viewport.offset = min(states[stateID].viewport.limit ?? 4096, (states[stateID].viewport.offset ?? 0) + 1)
            case .pageUp: states[stateID].viewport.offset = max(0, (states[stateID].viewport.offset ?? 0) - step)
            case .pageDown: states[stateID].viewport.offset = min(
                    states[stateID].viewport.limit ?? 4096,
                    (states[stateID].viewport.offset ?? 0) + step,
                )
            case .home: states[stateID].viewport.offset = 0
            case .end: states[stateID].viewport.offset = states[stateID].viewport.limit ?? 0
            default: return .rebuild(action: .unhandledKey(key))
            }
            return .repaint
        default: break
        }
        return .rebuild(action: .unhandledKey(key))
    }
}
