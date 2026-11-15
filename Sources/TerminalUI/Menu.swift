import TerminalUICore

/// A searchable modal menu. Search and highlighted selection are local by default.
@TerminalComponent
public struct Menu: TerminalView {
    @State private var query = ""
    @State private var selection: String?
    @State private var itemSelection: AnyHashable?
    @ApplicationContext private var application
    private var makeMenu: (Binding<String>, Binding<String?>, Binding<AnyHashable?>, TerminalApplicationContext) -> Element

    /// Local state lasts for this menu's mounted lifetime. Removing the menu resets it.
    public init(
        id: String, title: String, items: [MenuItem], initialSelection: String? = nil,
        notice: String? = nil
    ) {
        _selection = State(wrappedValue: initialSelection)
        makeMenu = { query, selection, _, _ in
            Self.boundMenu(id: id, title: title, items: items, query: query, selection: selection, notice: notice)
        }
    }

    /// Uses caller-owned search and selection state.
    public init(
        id: String, title: String, items: [MenuItem], query: Binding<String>,
        selection: Binding<String?>, notice: String? = nil
    ) {
        makeMenu = { _, _, _, _ in
            Self.boundMenu(id: id, title: title, items: items, query: query, selection: selection, notice: notice)
        }
    }

    /// Displays supplied values and leaves text/selection actions for the caller to handle.
    public init(
        id: String, title: String, items: [MenuItem], query: String,
        selection: String?, notice: String? = nil
    ) {
        makeMenu = { _, _, _, _ in
            .menu(id: id, title: title, items: items, query: query, selection: selection, notice: notice)
        }
    }

    /// Presents typed choices. Search and highlighted identity last for the mounted lifetime.
    /// Without an activation closure, choosing an item focuses its registered typed target.
    public init<Item: MenuItemDefinition & Hashable>(
        id: String, title: String, items: [Item], initialSelection: Item? = nil, notice: String? = nil,
        itemTitle: (Item) -> String = { $0.title }, shortcut: (Item) -> MenuShortcut = { $0.menuShortcut },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: ((Item) -> Void)? = nil
    ) {
        self.init(id: id, title: title, collection: MenuCollection(
            items: items, global: false, title: itemTitle,
            shortcut: shortcut, unavailableReason: unavailableReason
        ), initialSelection: initialSelection, notice: notice) { item, application in
            if let onActivate { onActivate(item) } else { application.focus(item) }
        }
    }

    public init<Item: Identifiable & Hashable>(
        id: String, title: String, items: [Item], initialSelection: Item? = nil, notice: String? = nil,
        itemTitle: (Item) -> String, shortcut: (Item) -> MenuShortcut = { _ in .automatic },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: ((Item) -> Void)? = nil
    ) {
        self.init(id: id, title: title, collection: MenuCollection(
            items: items, global: false, title: itemTitle,
            shortcut: shortcut, unavailableReason: unavailableReason
        ), initialSelection: initialSelection, notice: notice) { item, application in
            if let onActivate { onActivate(item) } else { application.focus(item) }
        }
    }

    /// An explicit activation closure replaces the default focus action.
    public init<Item: MenuItemDefinition>(
        id: String, title: String, items: [Item], initialSelection: Item? = nil, notice: String? = nil,
        itemTitle: (Item) -> String = { $0.title }, shortcut: (Item) -> MenuShortcut = { $0.menuShortcut },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: @escaping (Item) -> Void
    ) {
        self.init(id: id, title: title, collection: MenuCollection(
            items: items, global: false, title: itemTitle,
            shortcut: shortcut, unavailableReason: unavailableReason
        ), initialSelection: initialSelection, notice: notice) { item, _ in onActivate(item) }
    }

    /// Adapts existing identifiable values without requiring menu-specific conformance.
    public init<Item: Identifiable>(
        id: String, title: String, items: [Item], initialSelection: Item? = nil, notice: String? = nil,
        itemTitle: (Item) -> String, shortcut: (Item) -> MenuShortcut = { _ in .automatic },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: @escaping (Item) -> Void
    ) {
        self.init(id: id, title: title, collection: MenuCollection(
            items: items, global: false, title: itemTitle, shortcut: shortcut, unavailableReason: unavailableReason
        ), initialSelection: initialSelection, notice: notice) { item, _ in onActivate(item) }
    }

    private init<Item>(
        id: String, title: String, collection: MenuCollection<Item>, initialSelection: Item?, notice: String?,
        activate: @escaping (Item, TerminalApplicationContext) -> Void
    ) {
        _itemSelection = State(wrappedValue: (initialSelection ?? collection.items.first).map(collection.identity))
        makeMenu = { query, _, selection, application in
            collection.addingActivation(to: Self.boundMenu(
                id: id, title: title, items: collection.menuItems, query: query,
                selection: collection.binding(selection), notice: notice
            )) { item in
                activate(item, application)
            }
        }
    }

    public var body: some TerminalView {
        MenuContent(makeElement: { makeMenu($query, $selection, $itemSelection, application) })
    }

    private static func boundMenu(
        id: String, title: String, items: [MenuItem], query: Binding<String>,
        selection: Binding<String?>, notice: String?
    ) -> Element {
        let menu = bound(
            .menu(id: id, title: title, items: items, query: query.wrappedValue,
                  selection: selection.wrappedValue, notice: notice),
            event: .text, id: id + ".search", tracked: query.tracksState
        ) { query.wrappedValue = $0 }
        return bound(menu, event: .selection, id: id + ".items", tracked: selection.tracksState) {
            selection.wrappedValue = $0
        }
    }
}

private struct MenuContent: BuiltinView {
    typealias Body = Never
    let makeElement: () -> Element
}
