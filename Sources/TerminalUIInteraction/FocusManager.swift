import TerminalUICore

/// Owns modal restoration and successor selection when controls disappear.
package final class FocusManager {
    package private(set) var focusedID: String?
    private var previousFocus: String?
    private var modalActive = false
    private var previousOrder: [String] = []
    let tree: ElementTree

    package init(tree: ElementTree) {
        self.tree = tree
    }

    package func setFocus(_ id: String?) {
        focusedID = id
    }

    package func reset() {
        focusedID = nil
        previousFocus = nil
        modalActive = false
        previousOrder = []
    }

    package func requestFocus(_ id: String, in root: Element) -> Bool {
        guard tree.focusables(tree.modal(root) ?? root).contains(where: { $0.0 == id }) else { return false }
        focusedID = id
        return true
    }

    @discardableResult
    package func synchronize(_ root: Element) -> Bool {
        let previous = focusedID
        let activeModal = tree.modal(root)
        let enteringModal = activeModal != nil && !modalActive
        if enteringModal { previousFocus = focusedID }
        if activeModal == nil, modalActive { focusedID = previousFocus; previousFocus = nil }
        modalActive = activeModal != nil
        let controls = tree.focusables(activeModal ?? root)
        let order = controls.map(\.0)
        let startingScope = !order.contains(where: { $0 == focusedID }) && !previousOrder.contains(where: { order.contains($0) })
        if (startingScope || enteringModal), let preferred = controls.first(where: { $0.1.prefersInitialFocus }) {
            focusedID = preferred.0
        }
        if !order.contains(where: { $0 == focusedID }) {
            let oldIndex = focusedID.flatMap { previousOrder.firstIndex(of: $0) } ?? 0
            let successors = previousOrder.dropFirst(min(oldIndex + 1, previousOrder.count))
            focusedID = successors.first(where: { order.contains($0) }) ?? order.first
        }
        previousOrder = order
        return focusedID != previous
    }
}
