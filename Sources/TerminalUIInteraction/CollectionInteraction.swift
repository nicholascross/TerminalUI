import TerminalUICore

/// Keyboard selection and activation for application-controlled lists and tables.
package struct CollectionInteraction {
    let states: WidgetStateStore

    package init(states: WidgetStateStore) {
        self.states = states
    }

    package func handle(_ key: KeyEvent, control: Element) -> UIEventResult {
        let id: String, ids: [String], selection: String?, stateID: String
        switch control.kind {
        case let .list(value, rows, selected):
            id = value; ids = rows.map(\.id); selection = selected; stateID = "list:" + value
        case let .table(value, _, rows, selected, _):
            id = value; ids = rows.map(\.id); selection = selected; stateID = "table:" + value
        default: return .rebuild(action: .unhandledKey(key))
        }
        guard !ids.isEmpty else { return .rebuild(action: .unhandledKey(key)) }
        let index = selection.flatMap { ids.firstIndex(of: $0) } ?? 0
        let rowAction: String? = if case let .list(_, rows, _) = control.kind {
            rows[index].activationID
        } else {
            nil
        }
        if key == .enter, let submitID = rowAction ?? control.submitID {
            if case let .list(_, rows, _) = control.kind, !rows[index].isEnabled { return .rebuild(action: nil) }
            return .rebuild(action: .activated(submitID))
        }
        let step = max(1, states[stateID].viewport.height ?? 1)
        let next: Int
        switch key {
        case .up: next = max(0, index - 1)
        case .down: next = min(ids.count - 1, index + 1)
        case .pageUp: next = max(0, index - step)
        case .pageDown: next = min(ids.count - 1, index + step)
        case .home: next = 0
        case .end: next = ids.count - 1
        default: return .rebuild(action: .unhandledKey(key))
        }
        let height = max(1, states[stateID].viewport.height ?? 1)
        let offset = states[stateID].viewport.offset ?? 0
        if next < offset { states[stateID].viewport.offset = next }
        if next >= offset + height { states[stateID].viewport.offset = next - height + 1 }
        return .rebuild(action: .selectionChanged(id, ids[next]))
    }
}
