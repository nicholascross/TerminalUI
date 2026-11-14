import Foundation

extension Element {
    /// A horizontal menu. Apply selection changes to `focusedItem`; activation emits an item's ID.
    /// `selection` marks the current destination separately from keyboard focus.
    /// Item `globalShortcuts` work anywhere in the active scope, ahead of focused-control bindings.
    /// Hidden/disabled menus do not participate; unavailable matches consume without activation.
    /// Duplicate global shortcuts resolve to the first matching item in tree order.
    public static func menuBar(id: String, items: [MenuItem], selection: String?, focusedItem: String? = nil,
                               compact: Bool = false) -> Self {
        var bar = Self.custom(MenuBarWidget(id: id, items: items, selection: selection, focusedItem: focusedItem, compact: compact))
        bar.menuShortcutItems = items
        return bar
    }

    /// A searchable modal menu. Apply text/selection changes for `id.search` and `id.items`
    /// to application state. Enter emits the selected item's ID; Escape dismisses `id`.
    /// Character shortcuts apply only with an empty query; paste always remains search text.
    /// Global shortcuts apply to matching results only and cannot escape the active dialog.
    public static func menu(id: String, title: String, items: [MenuItem], query: String,
                            selection: String?, notice: String? = nil) -> Self {
        let matches = items.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        let selected = matches.first { $0.id == selection } ?? matches.first
        var search = Self.textField(id: id + ".search", value: query, placeholder: "Type to filter items")
        search.menuResultsID = id + ".items"
        var list = Self.list(id: id + ".items", rows: matches.map {
            ListRow(id: $0.id, title: ($0.shortcut.map { "\($0) " } ?? "") + $0.title,
                    isEnabled: $0.unavailableReason == nil, activationID: $0.id)
        }, selection: selected?.id).height(.fill())
        if let selected, selected.unavailableReason == nil {
            search = search.onSubmit(selected.id)
            list = list.onSubmit(selected.id)
        }
        if query.isEmpty {
            for item in items {
                if let shortcut = item.shortcut {
                    search = search.onKey(.character(shortcut), activate: item.id)
                    list = list.onKey(.character(shortcut), activate: item.id)
                }
            }
        }
        let reason = notice ?? selected?.unavailableReason
        var menu = Self.dialog(id: id, title: title, content: .column([
            search,
            list,
            .text("No matching items.").role(.secondary).visible(matches.isEmpty),
            reason.map { .paragraph($0).role(.warning) } ?? .text("").visible(false),
            .button("Return", id: id + ".back"),
            .keyHints("↓: results · Enter: open · Esc back")
        ]))
        menu.menuShortcutItems = matches
        return menu
    }
}
