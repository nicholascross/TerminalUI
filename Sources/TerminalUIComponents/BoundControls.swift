import TerminalUICore

@MainActor
private func bound(
    _ element: Element,
    event: ElementBehaviorEvent,
    id: String,
    tracked: Bool,
    setter: @escaping (String) -> Void,
) -> Element {
    var value = element
    var behavior = ElementBehavior(event, id: id) { payload in if let payload { setter(payload) } }
    behavior.requiresRefresh = !tracked
    value.behaviors.append(behavior)
    return value
}

@MainActor
public func TextField(id: String, text: Binding<String>, placeholder: String = "") -> Element {
    bound(.textField(id: id, value: text.wrappedValue, placeholder: placeholder), event: .text, id: id, tracked: text.tracksState) {
        text.wrappedValue = $0
    }
}

@MainActor
public func TextEditor(id: String, text: Binding<String>, placeholder: String = "") -> Element {
    bound(.textEditor(id: id, value: text.wrappedValue, placeholder: placeholder), event: .text, id: id, tracked: text.tracksState) {
        text.wrappedValue = $0
    }
}

@MainActor
public func List(id: String, rows: [ListRow], selection: Binding<String?>, lineLimit: Int = 1, rowSpacing: Int = 0) -> Element {
    bound(
        .list(id: id, rows: rows, selection: selection.wrappedValue, lineLimit: lineLimit, rowSpacing: rowSpacing),
        event: .selection,
        id: id,
        tracked: selection.tracksState,
    ) { selection.wrappedValue = $0 }
}

@MainActor
public func Table(id: String, columns: [TableColumn], rows: [TableRow], selection: Binding<String?>, bordered: Bool = false) -> Element {
    bound(
        .table(id: id, columns: columns, rows: rows, selection: selection.wrappedValue, bordered: bordered),
        event: .selection,
        id: id,
        tracked: selection.tracksState,
    ) { selection.wrappedValue = $0 }
}

@MainActor
public func Tabs(id: String, tabs: [Tab], selection: Binding<String?>) -> Element {
    bound(
        .tabs(id: id, tabs: tabs, selection: selection.wrappedValue).layoutSizing(width: .flexible(), height: .fixed(1)),
        event: .selection,
        id: id,
        tracked: selection.tracksState,
    ) { selection.wrappedValue = $0 }
}

@MainActor
public func List(id: String, rows: [ListRow], selection: Binding<String>, lineLimit: Int = 1, rowSpacing: Int = 0) -> Element {
    List(id: id, rows: rows, selection: selection.optionalSelection, lineLimit: lineLimit, rowSpacing: rowSpacing)
}

@MainActor
public func Table(id: String, columns: [TableColumn], rows: [TableRow], selection: Binding<String>, bordered: Bool = false) -> Element {
    Table(id: id, columns: columns, rows: rows, selection: selection.optionalSelection, bordered: bordered)
}

@MainActor
public func Tabs(id: String, tabs: [Tab], selection: Binding<String>) -> Element {
    Tabs(id: id, tabs: tabs, selection: selection.optionalSelection)
}

public extension Element {
    /// Handles an otherwise unclaimed action in this mounted scope. Return true to consume it.
    @MainActor func onAction(_ handler: @escaping @MainActor (UIAction) -> Bool) -> Element {
        var value = self
        value.actionHandlers.append(handler)
        return value
    }

    @MainActor func onSubmit(_ action: @escaping @MainActor () -> Void) -> Element {
        guard let id = controlID else { preconditionFailure("onSubmit requires a control") }
        var value = self
        value.behaviors.removeAll { $0.event == .submit }
        value.behaviors.append(ElementBehavior(.submit, id: id) { _ in action() })
        return value
    }

    @MainActor func onActivate(_ action: @escaping @MainActor () -> Void) -> Element {
        guard let id = controlID else { preconditionFailure("onActivate requires a control") }
        var value = self
        value.behaviors.removeAll { $0.event == .activate }
        value.behaviors.append(ElementBehavior(.activate, id: id) { _ in action() })
        return value
    }

    @MainActor func onDismiss(_ action: @escaping @MainActor () -> Void) -> Element {
        guard case let .dialog(id, _, _) = kind else { preconditionFailure("onDismiss requires a dialog") }
        var value = self
        value.behaviors.removeAll { $0.event == .dismiss }
        value.behaviors.append(ElementBehavior(.dismiss, id: id) { _ in action() })
        return value
    }
}

private extension Binding where Value == String {
    var optionalSelection: Binding<String?> {
        var binding = Binding<String?>(get: { wrappedValue }, set: { if let value = $0 { wrappedValue = value } })
        binding.tracksState = tracksState
        return binding
    }
}

/// Uses the ordinary searchable menu and its existing modal shortcut routing.
@MainActor
public func Menu(
    id: String,
    title: String,
    items: [MenuItem],
    query: Binding<String>,
    selection: Binding<String?>,
    notice: String? = nil,
) -> Element {
    let menu = bound(.menu(id: id, title: title, items: items, query: query.wrappedValue,
                           selection: selection.wrappedValue, notice: notice),
                     event: .text, id: id + ".search", tracked: query.tracksState) { query.wrappedValue = $0 }
    return bound(menu, event: .selection, id: id + ".items", tracked: selection.tracksState) { selection.wrappedValue = $0 }
}

@MainActor
public func MenuBar(
    id: String,
    items: [MenuItem],
    selection: String?,
    focusedItem: Binding<String?>,
    compact: Bool = false,
) -> Element {
    bound(.menuBar(id: id, items: items, selection: selection, focusedItem: focusedItem.wrappedValue, compact: compact)
        .layoutSizing(width: .flexible(), height: .fixed(1)), event: .selection, id: id, tracked: focusedItem.tracksState)
    {
        focusedItem.wrappedValue = $0
    }
}
