import TerminalUICore

@MainActor
extension ComponentRuntime {
    func scope(_ element: Element, owner: MountedComponent) -> Element {
        var value = element
        owner.actionHandlers.append(contentsOf: element.actionHandlers)
        value.actionHandlers.removeAll()
        func scoped(_ id: String) -> String {
            let result = owner.descriptor == nil ? id : owner.identity + ":" + id
            owner.localIDs[id] = result
            owner.actionIDs[result] = id
            return result
        }
        switch element.kind {
        case .button(let title, let id): value.kind = .button(title, scoped(id))
        case .field(let id, let text, let placeholder, let multiline): value.kind = .field(scoped(id), text, placeholder, multiline)
        case .list(let id, let rows, let selection): value.kind = .list(scoped(id), rows, selection)
        case .table(let id, let columns, let rows, let selection, let bordered): value.kind = .table(scoped(id), columns, rows, selection, bordered)
        case .dialog(let id, let title, let child): value.kind = .dialog(scoped(id), title, child)
        case .scroll(let id, let child): value.kind = .scroll(scoped(id), child)
        case .custom(let widget):
            if let id = widget.id { value.kind = .custom(ScopedWidget(base: widget, id: scoped(id))) }
        default: break
        }
        if let id = value.visibilityID { value.visibilityID = scoped(id) }
        if let id = value.menuResultsID { value.menuResultsID = scoped(id) }
        if let id = value.submitID { value.submitID = scoped(id) }
        value.keyActions = value.keyActions.map { ($0.key, scoped($0.actionID)) }
        for behavior in element.behaviors {
            let event: ElementBehaviorEvent
            let id: String
            if behavior.event == .focus {
                event = .focus
                id = ""
            } else if behavior.event == .submit {
                event = .activate
                id = scoped("@submit:" + behavior.controlID)
                value.submitID = id
            } else {
                event = behavior.event
                id = scoped(behavior.controlID)
            }
            owner.registrations[BehaviorAddress(event: event, id: id)] = behavior
        }
        value.behaviors.removeAll()
        return value
    }
}

/// Only the widget's control address changes; row/action payloads retain their application meaning.
private struct ScopedWidget: CustomWidget {
    let base: any CustomWidget
    let id: String?
    var isFocusable: Bool {
        base.isFocusable
    }

    func measure(context: WidgetMeasureContext) -> WidgetSize {
        base.measure(context: context)
    }

    func draw(in canvas: inout Canvas, context: WidgetDrawContext) {
        base.draw(in: &canvas, context: context)
    }

    func mouseTarget(at mouse: MouseEvent, context: WidgetMouseContext) -> String? {
        base.mouseTarget(at: mouse, context: context)
    }

    func respond(to key: KeyEvent, context: WidgetEventContext) -> WidgetResponse {
        translate(base.respond(to: key, context: context))
    }

    func respond(to mouse: MouseEvent, context: WidgetMouseContext) -> WidgetResponse {
        translate(base.respond(to: mouse, context: context))
    }

    private func translate(_ result: WidgetResponse) -> WidgetResponse {
        guard case .action(let action) = result, let old = base.id, let id else { return result }
        switch action {
        case .selectionChanged(let control, let value) where control == old: return .action(.selectionChanged(id, value))
        case .textChanged(let control, let value) where control == old: return .action(.textChanged(id, value))
        case .activated(old): return .action(.activated(id))
        default: return result
        }
    }
}
