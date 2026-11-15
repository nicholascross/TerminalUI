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

extension TextField {
    public init(id: String, text: Binding<String>, placeholder: String = "") {
        self.makeElement = {
            bound(.textField(id: id, value: text.wrappedValue, placeholder: placeholder), event: .text, id: id, tracked: text.tracksState) {
                text.wrappedValue = $0
            }
        }
    }
}

extension TextEditor {
    public init(id: String, text: Binding<String>, placeholder: String = "") {
        self.makeElement = {
            bound(.textEditor(id: id, value: text.wrappedValue, placeholder: placeholder), event: .text, id: id, tracked: text.tracksState) {
                text.wrappedValue = $0
            }
        }
    }
}

extension List {
    public init(id: String, rows: [ListRow], selection: Binding<String?>, lineLimit: Int = 1, rowSpacing: Int = 0) {
        self.makeElement = {
            bound(
                .list(id: id, rows: rows, selection: selection.wrappedValue, lineLimit: lineLimit, rowSpacing: rowSpacing),
                event: .selection,
                id: id,
                tracked: selection.tracksState,
            ) { selection.wrappedValue = $0 }
        }
    }
}

extension Table {
    public init(id: String, columns: [TableColumn], rows: [TableRow], selection: Binding<String?>, bordered: Bool = false) {
        self.makeElement = {
            bound(
                .table(id: id, columns: columns, rows: rows, selection: selection.wrappedValue, bordered: bordered),
                event: .selection,
                id: id,
                tracked: selection.tracksState,
            ) { selection.wrappedValue = $0 }
        }
    }
}

extension Tabs {
    public init(id: String, tabs: [Tab], selection: Binding<String?>) {
        self.makeElement = {
            bound(
                .tabs(id: id, tabs: tabs, selection: selection.wrappedValue).layoutSizing(width: .flexible(), height: .fixed(1)),
                event: .selection,
                id: id,
                tracked: selection.tracksState,
            ) { selection.wrappedValue = $0 }
        }
    }
}

extension List {
    public init(id: String, rows: [ListRow], selection: Binding<String>, lineLimit: Int = 1, rowSpacing: Int = 0) {
        self.init(id: id, rows: rows, selection: selection.optionalSelection, lineLimit: lineLimit, rowSpacing: rowSpacing)
    }
}

extension Table {
    public init(id: String, columns: [TableColumn], rows: [TableRow], selection: Binding<String>, bordered: Bool = false) {
        self.init(id: id, columns: columns, rows: rows, selection: selection.optionalSelection, bordered: bordered)
    }
}

extension Tabs {
    public init(id: String, tabs: [Tab], selection: Binding<String>) { self.init(id: id, tabs: tabs, selection: selection.optionalSelection) }
}

extension Menu {
    public init(
        id: String,
        title: String,
        items: [MenuItem],
        query: Binding<String>,
        selection: Binding<String?>,
        notice: String? = nil,
    ) {
        self.makeElement = {
            let menu = bound(
                .menu(
                    id: id, title: title, items: items, query: query.wrappedValue,
                    selection: selection.wrappedValue, notice: notice),
                event: .text, id: id + ".search", tracked: query.tracksState
            ) { query.wrappedValue = $0 }
            return bound(menu, event: .selection, id: id + ".items", tracked: selection.tracksState) { selection.wrappedValue = $0 }
        }
    }
}

extension MenuBar {
    public init(
        id: String,
        items: [MenuItem],
        selection: String?,
        focusedItem: Binding<String?>,
        compact: Bool = false,
    ) {
        self.makeElement = {
            bound(
                .menuBar(id: id, items: items, selection: selection, focusedItem: focusedItem.wrappedValue, compact: compact)
                    .layoutSizing(width: .flexible(), height: .fixed(1)), event: .selection, id: id, tracked: focusedItem.tracksState
            ) {
                focusedItem.wrappedValue = $0
            }
        }
    }
}

extension Binding where Value == String {
    fileprivate var optionalSelection: Binding<String?> {
        var binding = Binding<String?>(get: { wrappedValue }, set: { if let value = $0 { wrappedValue = value } })
        binding.tracksState = tracksState
        return binding
    }
}
