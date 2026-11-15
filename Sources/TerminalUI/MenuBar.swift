import TerminalUICore

/// A horizontal menu with local keyboard focus by default. Current destination remains caller-owned.
@TerminalComponent
public struct MenuBar: TerminalView {
    @State private var focusedItem: String?
    @State private var itemFocus: AnyHashable?
    @ApplicationContext private var application
    private var makeBar: (Binding<String?>, Binding<AnyHashable?>, TerminalApplicationContext) -> Element

    public init(id: String, items: [MenuItem], selection: String? = nil, compact: Bool = false) {
        _focusedItem = State(wrappedValue: selection)
        makeBar = { focus, _, _ in
            Self.boundBar(id: id, items: items, selection: selection, focusedItem: focus, compact: compact)
        }
    }

    public init(
        id: String, items: [MenuItem], selection: String?, focusedItem: Binding<String?>,
        compact: Bool = false
    ) {
        makeBar = { _, _, _ in
            Self.boundBar(id: id, items: items, selection: selection, focusedItem: focusedItem, compact: compact)
        }
    }

    /// Displays supplied focus and leaves selection actions for the caller to handle.
    public init(
        id: String, items: [MenuItem], selection: String?, focusedItem: String?,
        compact: Bool = false
    ) {
        makeBar = { _, _, _ in
            .menuBar(id: id, items: items, selection: selection, focusedItem: focusedItem, compact: compact)
                .layoutSizing(width: .flexible(), height: .fixed(1))
        }
    }

    /// Presents typed choices using their definition's defaults. The first matching shortcut wins.
    /// Without an activation closure, choosing an item focuses its registered typed target.
    public init<Item: MenuItemDefinition & Hashable>(
        id: String, items: [Item], activeItem: Item? = nil, compact: Bool = false,
        itemTitle: (Item) -> String = { $0.title }, shortcut: (Item) -> MenuShortcut = { $0.menuShortcut },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: ((Item) -> Void)? = nil
    ) {
        self.init(id: id, collection: MenuCollection(
            items: items, global: true, title: itemTitle,
            shortcut: shortcut, unavailableReason: unavailableReason
        ), activeItem: activeItem, compact: compact) { item, application in
            if let onActivate { onActivate(item) } else { application.focus(item) }
        }
    }

    public init<Item: Identifiable & Hashable>(
        id: String, items: [Item], activeItem: Item? = nil, compact: Bool = false,
        itemTitle: (Item) -> String, shortcut: (Item) -> MenuShortcut = { _ in .automatic },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: ((Item) -> Void)? = nil
    ) {
        self.init(id: id, collection: MenuCollection(
            items: items, global: true, title: itemTitle,
            shortcut: shortcut, unavailableReason: unavailableReason
        ), activeItem: activeItem, compact: compact) { item, application in
            if let onActivate { onActivate(item) } else { application.focus(item) }
        }
    }

    /// An explicit activation closure replaces the default focus action.
    public init<Item: MenuItemDefinition>(
        id: String, items: [Item], activeItem: Item? = nil, compact: Bool = false,
        itemTitle: (Item) -> String = { $0.title }, shortcut: (Item) -> MenuShortcut = { $0.menuShortcut },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: @escaping (Item) -> Void
    ) {
        self.init(id: id, collection: MenuCollection(
            items: items, global: true, title: itemTitle,
            shortcut: shortcut, unavailableReason: unavailableReason
        ), activeItem: activeItem, compact: compact) { item, _ in onActivate(item) }
    }

    /// Adapts existing identifiable values without requiring menu-specific conformance.
    public init<Item: Identifiable>(
        id: String, items: [Item], activeItem: Item? = nil, compact: Bool = false,
        itemTitle: (Item) -> String, shortcut: (Item) -> MenuShortcut = { _ in .automatic },
        unavailableReason: (Item) -> String? = { _ in nil },
        onActivate: @escaping (Item) -> Void
    ) {
        self.init(id: id, collection: MenuCollection(
            items: items, global: true, title: itemTitle, shortcut: shortcut, unavailableReason: unavailableReason
        ), activeItem: activeItem, compact: compact) { item, _ in onActivate(item) }
    }

    private init<Item>(
        id: String, collection: MenuCollection<Item>, activeItem: Item?, compact: Bool,
        activate: @escaping (Item, TerminalApplicationContext) -> Void
    ) {
        _itemFocus = State(wrappedValue: (activeItem ?? collection.items.first).map(collection.identity))
        makeBar = { _, focus, application in
            collection.addingActivation(to: Self.boundBar(
                id: id, items: collection.menuItems,
                selection: collection.payload(for: activeItem.map(collection.identity)),
                focusedItem: collection.binding(focus), compact: compact
            )) { item in
                activate(item, application)
            }
        }
    }

    public var body: some TerminalView {
        MenuBarContent(makeElement: { makeBar($focusedItem, $itemFocus, application) })
    }

    private static func boundBar(
        id: String, items: [MenuItem], selection: String?, focusedItem: Binding<String?>, compact: Bool
    ) -> Element {
        bound(
            .menuBar(id: id, items: items, selection: selection, focusedItem: focusedItem.wrappedValue, compact: compact)
                .layoutSizing(width: .flexible(), height: .fixed(1)),
            event: .selection, id: id, tracked: focusedItem.tracksState
        ) { focusedItem.wrappedValue = $0 }
    }
}

private struct MenuBarContent: BuiltinView {
    typealias Body = Never
    let makeElement: () -> Element
}
