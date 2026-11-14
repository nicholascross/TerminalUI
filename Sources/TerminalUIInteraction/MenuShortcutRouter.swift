import TerminalUICore

package struct MenuShortcutRouter {
    package init() {}

    /// Only explicit modified shortcuts participate; data and focus traversal keep their meanings.
    package func route(_ key: KeyEvent, in root: Element, active: Element) -> UIEventResult? {
        switch key {
        case .altCharacter, .controlCharacter, .controlC, .controlD, .controlP: break
        default: return nil
        }
        let dialogID: String? = if case let .dialog(id, _, _) = active.kind { id } else { nil }
        return findMenuShortcut(key, in: root, dialogID: dialogID)
    }

    private func findMenuShortcut(_ key: KeyEvent, in element: Element, dialogID: String?) -> UIEventResult? {
        guard element.isVisible, element.isEnabled else { return nil }
        var remainingDialogID = dialogID
        if case let .dialog(id, _, _) = element.kind, id == dialogID { remainingDialogID = nil }
        if remainingDialogID == nil, let item = element.menuShortcutItems.first(where: { $0.globalShortcuts.contains(key) }) {
            return .rebuild(action: item.unavailableReason == nil ? .activated(item.id) : nil)
        }
        let children: [Element] = if case let .overlay(_, top) = element.kind, remainingDialogID == nil {
            [top]
        } else {
            element.children
        }
        // Tree order resolves duplicate bindings, including an unavailable first match.
        for child in children {
            if let result = findMenuShortcut(key, in: child, dialogID: remainingDialogID) { return result }
        }
        return nil
    }
}
