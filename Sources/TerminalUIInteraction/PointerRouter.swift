import TerminalUICore
import TerminalUILayoutEngine
import TerminalUIText

/// Owns pointer press identity and routes only against a live geometry view.
package final class PointerRouter {
    private let states: WidgetStateStore
    private let focus: FocusManager
    private let tree: ElementTree
    private let coordinates: EditorCoordinates
    private var size: WidgetSize?
    private var pressedMouseTarget: (control: String, item: String?, modal: String?)?

    package init(states: WidgetStateStore, focus: FocusManager, tree: ElementTree, coordinates: EditorCoordinates) {
        self.states = states
        self.focus = focus
        self.tree = tree
        self.coordinates = coordinates
    }

    package func cancelPress() {
        pressedMouseTarget = nil
    }

    package func resize(to size: WidgetSize) {
        if self.size != size { cancelPress() }
        self.size = size
    }

    /// Routes mouse input against the current rendered tree. Render again after geometry-changing input.
    /// Without current geometry, input is ignored. Mouse focus and actions follow the same modal rules as keys.
    package func handle(_ mouse: MouseEvent, geometry: RenderedGeometry?, theme: Theme) -> InteractionOutcome {
        guard let root = geometry?.root else {
            pressedMouseTarget = nil
            return .unchanged
        }
        let path = mousePath(root, at: mouse)
        let activeModal = mouseModalID(root.element)
        if let activeModal, !path.contains(where: {
            if case let .dialog(id, _, _) = $0.element.kind { return id == activeModal }
            return false
        }) {
            pressedMouseTarget = nil
            return .unchanged
        }
        if mouse.kind == .scrollUp || mouse.kind == .scrollDown {
            pressedMouseTarget = nil
            return scrollWithMouse(mouse, path: path, theme: theme)
        }
        guard mouse.button == .primary else {
            if mouse.kind == .press { pressedMouseTarget = nil }
            return .unchanged
        }
        let target = path.reversed().first { isMouseControl($0.element) }
        guard let target, target.mouse?.enabled == true else {
            pressedMouseTarget = nil
            return .unchanged
        }
        let item = mouseItem(target, at: mouse, theme: theme)
        if mouse.kind == .release {
            let pressed = pressedMouseTarget
            pressedMouseTarget = nil
            guard let pressed, pressed.control == target.element.controlID, pressed.item == item,
                  pressed.modal == activeModal else { return .unchanged }
            return releaseMouse(mouse, on: target, item: item, theme: theme)
        }
        if case .custom = target.element.kind, item == nil {
            pressedMouseTarget = nil
        } else {
            pressedMouseTarget = target.element.controlID.map { ($0, item, activeModal) }
        }
        states.resumeAutomaticVisibility()
        return pressMouse(mouse, on: target, item: item, theme: theme)
    }

    private func mouseModalID(_ root: Element) -> String? {
        if let active = tree.modal(root), case let .dialog(id, _, _) = active.kind { return id }
        return nil
    }

    private func mousePath(_ node: LayoutNode, at mouse: MouseEvent) -> [LayoutNode] {
        guard let geometry = node.mouse, geometry.clip.contains(mouse) else { return [] }
        let children: [LayoutNode] = if case .overlay = node.element.kind {
            Array(node.children.suffix(1))
        } else {
            node.children
        }
        for child in children.reversed() {
            let path = mousePath(child, at: mouse)
            if !path.isEmpty { return [node] + path }
        }
        return [node]
    }

    private func isMouseControl(_ element: Element) -> Bool {
        switch element.kind {
        case .button, .field, .list, .table, .scroll, .custom, .panel, .dialog: true
        default: false
        }
    }

    private func mouseContext(_ node: LayoutNode, theme: Theme) -> WidgetMouseContext {
        let bounds = node.mouse?.bounds
        return WidgetMouseContext(size: WidgetSize(width: bounds?.width ?? 0, height: bounds?.height ?? 0),
                                  focused: node.element.controlID != nil && focus.focusedID == node.element.controlID, theme: theme)
    }

    private func localMouse(_ mouse: MouseEvent, on node: LayoutNode) -> MouseEvent {
        mouse.translated(column: node.mouse?.bounds.column ?? 0, row: node.mouse?.bounds.row ?? 0)
    }

    private func mouseItem(_ node: LayoutNode, at mouse: MouseEvent, theme: Theme) -> String? {
        if case let .custom(widget) = node.element.kind {
            return widget.mouseTarget(at: localMouse(mouse, on: node), context: mouseContext(node, theme: theme))
        }
        return node.mouse?.rows.first { $0.bounds.contains(mouse) }?.id
    }

    private func pressMouse(_ mouse: MouseEvent, on node: LayoutNode, item: String?, theme: Theme) -> InteractionOutcome {
        let element = node.element
        switch element.kind {
        case .panel, .dialog:
            let controls = tree.focusables(element)
            if !controls.contains(where: { $0.0 == focus.focusedID }), let first = controls.first { focus.setFocus(first.0) }
        case let .custom(widget):
            let context = mouseContext(node, theme: theme)
            if widget.isFocusable { focus.setFocus(widget.id) }
            guard item != nil else { return .rebuild(nil) }
            return mouseResponse(widget.respond(to: localMouse(mouse, on: node), context: context))
        case let .field(id, value, _, multiline):
            focus.setFocus(id)
            placeCaret(mouse, node: node, id: id, value: value, multiline: multiline)
        case let .list(id, _, _), let .table(id, _, _, _, _):
            focus.setFocus(id)
            return .rebuild(item.map { .selectionChanged(id, $0) })
        default: focus.setFocus(element.controlID)
        }
        return .rebuild(nil)
    }

    private func releaseMouse(_ mouse: MouseEvent, on node: LayoutNode, item: String?, theme: Theme) -> InteractionOutcome {
        switch node.element.kind {
        case let .button(_, id): return .rebuild(.activated(id))
        case let .list(_, rows, _):
            guard let row = rows.first(where: { $0.id == item }), row.isEnabled, let action = row.activationID else { return .unchanged }
            return .rebuild(.activated(action))
        case let .custom(widget):
            return mouseResponse(widget.respond(to: localMouse(mouse, on: node), context: mouseContext(node, theme: theme)))
        default: return .unchanged
        }
    }

    private func placeCaret(_ mouse: MouseEvent, node: LayoutNode, id: String, value: String, multiline: Bool) {
        guard let geometry = node.mouse else { return }
        let local = localMouse(mouse, on: node)
        let chars = Array(value.prefix(100000))
        let coordinates = coordinates.positions(chars, width: max(1, geometry.bounds.width), multiline: multiline)
        let row = min(local.row + geometry.verticalOffset, coordinates.last?.row ?? 0)
        let column = local.column + geometry.horizontalOffset
        let candidates = coordinates.indices.filter { coordinates[$0].row == row }
        let caret = candidates.min { abs(coordinates[$0].column - column) < abs(coordinates[$1].column - column) } ?? chars.count
        let stateID = (multiline ? "editor:" : "field:") + id
        states[stateID].editor.caret = caret
        states[stateID].editor.selection = nil
        states[stateID].editor.preferredColumn = nil
    }

    private func scrollState(_ element: Element) -> (id: String, state: String)? {
        switch element.kind {
        case let .scroll(id, _): (id, "scroll:" + id)
        case let .list(id, _, _): (id, "list:" + id)
        case let .table(id, _, _, _, _): (id, "table:" + id)
        case .field(let id, _, _, true): (id, "editor:" + id)
        default: nil
        }
    }

    private func scrollWithMouse(_ mouse: MouseEvent, path: [LayoutNode], theme: Theme) -> InteractionOutcome {
        for node in path.reversed() where node.mouse?.enabled == true {
            if case let .custom(widget) = node.element.kind {
                let response = widget.respond(to: localMouse(mouse, on: node), context: mouseContext(node, theme: theme))
                if case .unhandled = response {} else { return mouseResponse(response) }
            }
            guard let target = scrollState(node.element) else { continue }
            let previous = states[target.state].viewport.offset ?? 0
            let offset = min(states[target.state].viewport.limit ?? 0, max(0, previous + (mouse.kind == .scrollUp ? -3 : 3)))
            guard offset != previous else { continue }
            states[target.state].viewport.offset = offset
            states.markManuallyScrolled(Set(path.compactMap { scrollState($0.element)?.state }))
            return .viewport(target.id)
        }
        return .unchanged
    }

    private func mouseResponse(_ response: WidgetResponse) -> InteractionOutcome {
        if case let .action(action) = response { return .rebuild(action) }
        return .rebuild(nil)
    }
}
