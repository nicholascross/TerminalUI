import TerminalUICore

/// Queries retain distinct policies for modal, focus, state and visibility traversal.
package struct ElementTree {
    package init() {}
    package func stateKeys(_ element: Element) -> [String] {
        guard element.isVisible else { return [] }
        let own = element.stateKey.map { [$0] } ?? []
        return own + element.children.flatMap { stateKeys($0) }
    }

    package func modal(_ element: Element) -> Element? {
        guard element.isVisible else { return nil }
        if case .dialog = element.kind { return element }
        for child in element.children.reversed() {
            if let modal = modal(child) { return modal }
        }
        return nil
    }

    package func focusables(_ element: Element) -> [(String, Element)] {
        guard element.isVisible, element.isEnabled else { return [] }
        if case let .overlay(_, top) = element.kind { return focusables(top) }
        let own: [(String, Element)] = if case let .custom(widget) = element.kind, !widget.isFocusable {
            []
        } else {
            element.controlID.map { [($0, element)] } ?? []
        }
        return own + element.children.flatMap { focusables($0) }
    }

    package func containsTarget(_ element: Element, id: String) -> Bool {
        guard element.isVisible else { return false }
        if element.visibilityID == id || element.controlID == id { return true }
        return element.children.contains { containsTarget($0, id: id) }
    }

    package func containsFocus(_ element: Element, id: String?) -> Bool {
        guard element.isVisible, element.isEnabled, let id else { return false }
        if element.controlID == id { return true }
        if case let .overlay(_, top) = element.kind { return containsFocus(top, id: id) }
        return element.children.contains { containsFocus($0, id: id) }
    }
}
