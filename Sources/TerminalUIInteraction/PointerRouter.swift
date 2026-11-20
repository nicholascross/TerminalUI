import Foundation
import TerminalUICore
import TerminalUILayoutEngine
import TerminalUIText

/// Owns pointer press identity and routes only against a live geometry view.
package final class PointerRouter {
    private struct Drag {
        let start: MouseEvent
        let anchor: Range<Int>
        var position: MouseEvent?
        var hasScrolled = false
        var needsEndpointRefresh = false
    }

    private struct SelectionTarget {
        let node: LayoutNode
        let element: Element
        let viewports: [LayoutNode]

        init(node: LayoutNode, path: [LayoutNode]) {
            self.node = node
            element = node.element
            viewports = path.filter {
                if case .scroll = $0.element.kind { return true }
                return false
            }
        }
    }

    private struct ScrollStep {
        let id: String
        let state: String
        let offset: Int
    }

    private struct PanelDrag {
        let node: LayoutNode
        let bounds: MouseRect
        let index: Int
        let resize: PanelResize
        let initial: StackResizeAllocation
        let previous: StackResizeAllocation?
        let start: Int
        var lastSize: Int

        var startSize: Int { initial.sizes[index] }
    }

    private let states: WidgetStateStore
    private let focus: FocusManager
    private let tree: ElementTree
    private let coordinates: EditorCoordinates
    private var size: WidgetSize?
    private var pressedMouseTarget: (control: String, item: String?, modal: String?)?
    private var drag: Drag?
    private var selectionTarget: SelectionTarget?
    private var panelDrag: PanelDrag?
    package private(set) var textSelection: SelectableCell?

    package init(states: WidgetStateStore, focus: FocusManager, tree: ElementTree, coordinates: EditorCoordinates) {
        self.states = states
        self.focus = focus
        self.tree = tree
        self.coordinates = coordinates
    }

    @discardableResult
    package func cancelPress(preservingSelection: Bool = false) -> LayoutNode? {
        pressedMouseTarget = nil
        if !preservingSelection { clearSelection() }
        return cancelPanelDrag()
    }

    package var isResizingPanel: Bool { panelDrag != nil }

    @discardableResult
    private func cancelPanelDrag() -> LayoutNode? {
        guard let panelDrag else { return nil }
        self.panelDrag = nil
        guard panelDrag.lastSize != panelDrag.startSize else { return nil }
        panelDrag.node.panelResizeAllocation = panelDrag.previous
        return panelDrag.node
    }

    private func clearSelection() {
        drag = nil
        selectionTarget = nil
        textSelection = nil
    }

    package func reconcileSelection(in root: LayoutNode) {
        guard let target = selectionTarget else { return }
        let old = target.element
        let retained = selectionPath(in: root) {
            $0 === target.node && $0.element.visibilityID == old.visibilityID
                && $0.element.compositionPath == old.compositionPath
        }
        let path = retained ?? old.visibilityID.flatMap { id in
            guard let path = selectionPath(in: root, matching: { $0.element.visibilityID == id }),
                  let match = path.last,
                  selectionPath(in: root, matching: { $0 !== match && $0.element.visibilityID == id }) == nil else { return nil }
            return path
        }
        guard let path, let node = path.last, canHit(path, modal: mouseModalID(root.element)),
              hasSameSelectionSource(old, node.element) else {
            clearSelection()
            return
        }
        selectionTarget = SelectionTarget(node: node, path: path)
        if let textSelection {
            self.textSelection = SelectableCell(owner: ObjectIdentifier(node), source: textSelection.source)
        }
    }

    private func selectionPath(in node: LayoutNode, matching matches: (LayoutNode) -> Bool) -> [LayoutNode]? {
        guard node.element.isVisible, node.element.isEnabled else { return nil }
        if node.element.isTextSelectable, matches(node) { return [node] }
        for child in mouseChildren(of: node) {
            if let path = selectionPath(in: child, matching: matches) { return [node] + path }
        }
        return nil
    }

    private func hasSameSelectionSource(_ old: Element, _ new: Element) -> Bool {
        switch (old.kind, new.kind) {
        case let (.text(a), .text(b)), let (.paragraph(a), .paragraph(b)):
            return a.utf8.elementsEqual(b.utf8)
        case let (.styledParagraph(a), .styledParagraph(b)):
            if a.count == b.count, zip(a, b).allSatisfy({ $0.text.utf8.elementsEqual($1.text.utf8) }) { return true }
            return a.lazy.flatMap { $0.text.utf8 }.elementsEqual(b.lazy.flatMap { $0.text.utf8 })
        case let (.paragraph(text), .styledParagraph(spans)), let (.styledParagraph(spans), .paragraph(text)):
            return text.utf8.elementsEqual(spans.lazy.flatMap { $0.text.utf8 })
        default:
            return false
        }
    }

    @discardableResult
    package func resize(to size: WidgetSize) -> LayoutNode? {
        let restored = self.size != size ? cancelPress() : nil
        self.size = size
        return restored
    }

    /// Clear a captured drag if its panel, parent or live geometry changed during a repaint.
    package func validatePanelDrag(in geometry: RenderedGeometry?) -> LayoutNode? {
        guard let panelDrag else { return nil }
        if let root = geometry?.root, panelTarget(for: panelDrag, in: root) != nil { return nil }
        return cancelPanelDrag()
    }

    /// Routes mouse input against the current rendered tree. Render again after geometry-changing input.
    /// Without current geometry, input is ignored. Mouse focus and actions follow the same modal rules as keys.
    package func handle(_ mouse: MouseEvent, geometry: RenderedGeometry?, theme: Theme) -> InteractionOutcome {
        guard let geometry, let root = geometry.root else {
            return cancelPress().map { .panelResize($0, nil) } ?? .unchanged
        }
        if let panelDrag {
            if mouse.kind == .press {
                if let restored = cancelPanelDrag() { return .panelResize(restored, nil) }
            } else {
                guard mouse.button == .primary, mouse.kind == .drag || mouse.kind == .release else { return .unchanged }
                return updatePanelDrag(panelDrag, at: mouse, in: root)
            }
        }
        let wheel = mouse.kind == .scrollUp || mouse.kind == .scrollDown
        if mouse.kind == .press { clearSelection() }
        if wheel, let drag {
            self.drag?.position = mouse
            let outcome = scrollSelection(wheelRows: mouse.kind == .scrollUp ? -3 : 3)
            if case .unchanged = outcome, drag.position?.column != mouse.column || drag.position?.row != mouse.row {
                refreshSelection(in: geometry)
                return .textSelection(copy: nil)
            }
            return outcome
        }
        if mouse.button == .primary, let drag, mouse.kind == .drag || mouse.kind == .release {
            return updateSelection(drag, at: mouse, geometry: geometry)
        }
        if mouse.kind == .drag {
            pressedMouseTarget = nil
            return .unchanged
        }
        let path = mousePath(root, at: mouse)
        let activeModal = mouseModalID(root.element)
        if !canHit(path, modal: activeModal) {
            pressedMouseTarget = nil
            return .unchanged
        }
        if wheel {
            pressedMouseTarget = nil
            return scrollWithMouse(mouse, path: path, theme: theme)
        }
        guard mouse.button == .primary else {
            if mouse.kind == .press { pressedMouseTarget = nil }
            return .unchanged
        }
        if mouse.kind == .press, !mouse.shift, !mouse.alt, !mouse.control, beginPanelDrag(at: mouse, on: path) {
            return .unchanged
        }
        if mouse.kind == .press, !mouse.shift, !mouse.alt, !mouse.control,
           let anchor = geometry.selectableCell(at: mouse),
           let target = path.last, ObjectIdentifier(target) == anchor.owner {
            pressedMouseTarget = nil
            selectionTarget = SelectionTarget(node: target, path: path)
            drag = Drag(start: mouse, anchor: anchor.source)
            return .textSelection(copy: nil)
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

    private func beginPanelDrag(at mouse: MouseEvent, on path: [LayoutNode]) -> Bool {
        for node in path.reversed() {
            guard let geometry = node.mouse, let resize = geometry.resize,
                  let handle = resize.handles.first(where: { handle in
                      handle.bounds.contains(mouse) && path.contains { $0 === handle.panel }
                  }), let panel = handle.panel.element.panelResize else { continue }
            panelDrag = PanelDrag(node: node, bounds: geometry.bounds, index: handle.index, resize: panel,
                                  initial: resize.allocation, previous: node.panelResizeAllocation,
                                  start: resizeCoordinate(mouse, edge: panel.edge), lastSize: resize.allocation.sizes[handle.index])
            pressedMouseTarget = nil
            return true
        }
        return false
    }

    private func panelTarget(for drag: PanelDrag, in root: LayoutNode) -> LayoutNode? {
        let vertical = drag.resize.edge.vertical
        guard let geometry = drag.node.mouse,
              vertical ? (geometry.bounds.row, geometry.bounds.height) == (drag.bounds.row, drag.bounds.height)
                  : (geometry.bounds.column, geometry.bounds.width) == (drag.bounds.column, drag.bounds.width),
              let resize = geometry.resize,
              resize.allocation.contract == drag.initial.contract,
              let handle = resize.handles.first(where: { $0.index == drag.index && $0.panel.element.panelResize == drag.resize }) else { return nil }
        let position = MouseEvent(.press, column: handle.bounds.column, row: handle.bounds.row)
        let path = mousePath(root, at: position)
        guard path.contains(where: { $0 === drag.node }), path.contains(where: { $0 === handle.panel }),
              canHit(path, modal: mouseModalID(root.element)) else { return nil }
        return handle.panel
    }

    private func updatePanelDrag(_ drag: PanelDrag, at mouse: MouseEvent, in root: LayoutNode) -> InteractionOutcome {
        guard let target = panelTarget(for: drag, in: root) else {
            return cancelPanelDrag().map { .panelResize($0, nil) } ?? .unchanged
        }
        let displacement = resizeCoordinate(mouse, edge: drag.resize.edge) - drag.start
        let requested = drag.startSize + (drag.resize.edge.isEnd ? displacement : -displacement)
        var allocation = drag.initial
        allocation.resize(drag.index, to: requested)
        let size = allocation.sizes[drag.index]
        if mouse.kind == .release { panelDrag = nil }
        if mouse.kind == .release, size != drag.startSize {
            states[drag.resize.stateKey].panelSize = size
            allocation.rememberSize(at: drag.index)
            drag.node.panelResizeAllocation = allocation
            let commit = target.element.panelResizeDidEnd.map { PanelResizeCommit(callback: $0, size: size) }
            return .panelResize(drag.node, commit)
        }
        guard size != drag.lastSize else { return .unchanged }
        panelDrag?.lastSize = size
        drag.node.panelResizeAllocation = size == drag.startSize ? drag.previous : allocation
        return .panelResize(drag.node, nil)
    }

    private func resizeCoordinate(_ mouse: MouseEvent, edge: PanelResizeEdge) -> Int {
        // A release outside the surface can still move to the far limit.
        min(8192, max(-4096, edge.vertical ? mouse.row : mouse.column))
    }

    private func canHit(_ path: [LayoutNode], modal: String?) -> Bool {
        guard let modal else { return true }
        return path.contains {
            if case let .dialog(id, _, _) = $0.element.kind { return id == modal }
            return false
        }
    }

    private func updateSelection(_ drag: Drag, at mouse: MouseEvent, geometry: RenderedGeometry) -> InteractionOutcome {
        self.drag?.position = mouse
        if drag.position?.column != mouse.column || drag.position?.row != mouse.row || drag.needsEndpointRefresh {
            refreshSelection(in: geometry)
        }
        guard mouse.kind == .release else { return .textSelection(copy: nil) }
        self.drag = nil
        let text = textSelection.flatMap { selection in
            selectionTarget.flatMap { selectionText(in: $0.node.element, range: selection.source) }
        }
        if textSelection == nil { selectionTarget = nil }
        return .textSelection(copy: text)
    }

    /// Scrolling moves the source under a stationary pointer. Other repaints preserve the source range.
    package func refreshScrolledSelection(in geometry: RenderedGeometry) {
        if drag?.needsEndpointRefresh == true { refreshSelection(in: geometry) }
    }

    private func refreshSelection(in geometry: RenderedGeometry) {
        guard let drag, let position = drag.position, let target = selectionTarget else { return }
        self.drag?.needsEndpointRefresh = false
        let atStart = position.column == drag.start.column && position.row == drag.start.row
        if atStart, !drag.hasScrolled {
            textSelection = nil
            return
        }
        // A viewport can briefly contain only blank lines of the selected text.
        let owner = ObjectIdentifier(target.node)
        guard let endpoint = geometry.selectionEndpoint(for: owner, at: position) else { return }
        let anchor = drag.anchor
        if atStart, endpoint.source == anchor {
            textSelection = nil
            return
        }
        let range = min(anchor.lowerBound, endpoint.source.lowerBound) ..< max(anchor.upperBound, endpoint.source.upperBound)
        textSelection = SelectableCell(owner: owner, source: range)
    }

    package var canAutoscrollSelection: Bool {
        drag.flatMap { selectionScrollStep($0, wheelRows: nil) } != nil
    }

    package func autoscrollSelection() -> InteractionOutcome {
        scrollSelection(wheelRows: nil)
    }

    private func scrollSelection(wheelRows: Int?) -> InteractionOutcome {
        guard let drag, let target = selectionTarget,
              let step = selectionScrollStep(drag, wheelRows: wheelRows) else { return .unchanged }
        self.drag?.hasScrolled = true
        self.drag?.needsEndpointRefresh = true
        return applyScroll(step, along: target.viewports)
    }

    private func selectionScrollStep(_ drag: Drag, wheelRows: Int?) -> ScrollStep? {
        guard let position = drag.position, wheelRows != nil || position.kind == .drag,
              let target = selectionTarget, let bounds = target.node.mouse?.bounds else { return nil }
        for viewport in target.viewports.reversed() {
            guard let clip = viewport.mouse?.clip, clip.height > 0 else { continue }
            let bottom = clip.row + clip.height
            let rows: Int
            if let wheelRows {
                rows = wheelRows
            } else if position.row < clip.row || (clip.height > 1 && position.row == clip.row) {
                rows = -1
            } else if position.row >= bottom || (clip.height > 1 && position.row == bottom - 1) {
                rows = 1
            } else {
                continue
            }
            let available = rows < 0 ? clip.row - bounds.row : bounds.row + bounds.height - bottom
            guard available > 0 else { continue }
            let step = min(available, abs(rows)) * (rows < 0 ? -1 : 1)
            if let scroll = scrollStep(for: viewport, rows: step) { return scroll }
        }
        return nil
    }

    private func selectionText(in element: Element, range: Range<Int>) -> String? {
        switch element.kind {
        case let .text(text), let .paragraph(text):
            return String(bytes: text.utf8.dropFirst(range.lowerBound).prefix(range.count), encoding: .utf8)
        case let .styledParagraph(spans):
            var text = ""
            var offset = 0
            for span in spans {
                let bytes = span.text.utf8
                let end = offset + bytes.count
                let lower = max(offset, range.lowerBound)
                let upper = min(end, range.upperBound)
                if lower < upper {
                    let selected = bytes.dropFirst(lower - offset).prefix(upper - lower)
                    guard let fragment = String(bytes: selected, encoding: .utf8) else { return nil }
                    text += fragment
                }
                if end >= range.upperBound { break }
                offset = end
            }
            return text
        default: return nil
        }
    }

    private func mouseModalID(_ root: Element) -> String? {
        if let active = tree.modal(root), case let .dialog(id, _, _) = active.kind { return id }
        return nil
    }

    private func mousePath(_ node: LayoutNode, at mouse: MouseEvent) -> [LayoutNode] {
        guard let geometry = node.mouse, geometry.clip.contains(mouse) else { return [] }
        for child in mouseChildren(of: node).reversed() {
            let path = mousePath(child, at: mouse)
            if !path.isEmpty { return [node] + path }
        }
        return [node]
    }

    private func mouseChildren(of node: LayoutNode) -> ArraySlice<LayoutNode> {
        if case .overlay = node.element.kind { return node.children.suffix(1) }
        return node.children[...]
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
            if let step = scrollStep(for: node, rows: mouse.kind == .scrollUp ? -3 : 3) {
                return applyScroll(step, along: path)
            }
        }
        return .unchanged
    }

    private func scrollStep(for node: LayoutNode, rows: Int) -> ScrollStep? {
        guard let target = scrollState(node.element) else { return nil }
        let viewport = states[target.state].viewport
        let previous = viewport.offset ?? 0
        let offset = min(viewport.limit ?? 0, max(0, previous + rows))
        guard offset != previous else { return nil }
        return ScrollStep(id: target.id, state: target.state, offset: offset)
    }

    private func applyScroll(_ step: ScrollStep, along path: [LayoutNode]) -> InteractionOutcome {
        states[step.state].viewport.offset = step.offset
        states.markManuallyScrolled(Set(path.compactMap { scrollState($0.element)?.state }))
        return .viewport(step.id)
    }

    private func mouseResponse(_ response: WidgetResponse) -> InteractionOutcome {
        if case let .action(action) = response { return .rebuild(action) }
        return .rebuild(nil)
    }
}
