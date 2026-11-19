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
        if let focusValue = element.focusValue, let id = element.controlID {
            owner.focusTargets.append((focusValue, scoped(id)))
        }
        owner.focusValueObservers.append(contentsOf: element.focusValueObservers)
        value.focusValue = nil
        value.focusValueObservers.removeAll()
        switch element.kind {
        case .button(let title, let id): value.kind = .button(title, scoped(id))
        case .field(let id, let text, let placeholder, let multiline): value.kind = .field(scoped(id), text, placeholder, multiline)
        case .list(let id, let rows, let selection):
            value.kind = .list(scoped(id), rows.map { row in
                guard let action = row.activationID, let local = element.localMenuActionIDs[action] else { return row }
                return ListRow(id: row.id, title: row.title, isEnabled: row.isEnabled, activationID: scoped(local))
            }, selection)
        case .table(let id, let columns, let rows, let selection, let bordered): value.kind = .table(scoped(id), columns, rows, selection, bordered)
        case .dialog(let id, let title, let child): value.kind = .dialog(scoped(id), title, child)
        case .scroll(let id, let child): value.kind = .scroll(scoped(id), child)
        case .custom(let widget):
            if let id = widget.id {
                let actions = element.localMenuActionIDs.mapValues(scoped)
                value.kind = .custom(ScopedWidget(base: widget, id: scoped(id), actions: actions))
            }
        default: break
        }
        if let id = value.visibilityID { value.visibilityID = scoped(id) }
        if let resize = value.panelResize, owner.descriptor != nil {
            value.panelResize?.id = owner.identity + ":" + resize.id
        }
        if let id = value.menuResultsID { value.menuResultsID = scoped(id) }
        if let id = value.submitID { value.submitID = scoped(element.localMenuActionIDs[id] ?? id) }
        value.menuShortcutItems = element.menuShortcutItems.map { item in
            let buttonID: String? = if case .button(_, let id) = element.kind { id } else { nil }
            guard let local = element.localMenuActionIDs[item.id] ?? (item.id == buttonID ? buttonID : nil) else { return item }
            return MenuItem(id: scoped(local), title: item.title, shortcut: item.shortcut,
                            unavailableReason: item.unavailableReason, globalShortcuts: item.globalShortcuts)
        }
        value.keyActions = value.keyActions.map { ($0.key, scoped(element.localMenuActionIDs[$0.actionID] ?? $0.actionID)) }
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
            var registration = behavior
            if event == .activate, element.localMenuActionIDs.values.contains(behavior.controlID) {
                registration.beforeInvoke = element.menuActivationObservers
            }
            owner.registrations[BehaviorAddress(event: event, id: id)] = registration
        }
        value.behaviors.removeAll()
        value.menuActivationObservers.removeAll()
        value.isCollectionMenu = false
        return value
    }
}

/// Control addresses and declared callback actions are scoped; other payloads retain their application meaning.
private struct ScopedWidget: CustomWidget {
    let base: any CustomWidget
    let id: String?
    let actions: [String: String]
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
        case .activated(let action): return .action(.activated(actions[action] ?? (action == old ? id : action)))
        default: return result
        }
    }
}
