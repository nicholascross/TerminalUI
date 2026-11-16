import TerminalUICore

/// Presentation defaults for a typed menu choice. Activation belongs to the menu's caller.
public protocol MenuItemDefinition: Identifiable {
    var title: String { get }
    var menuShortcut: MenuShortcut { get }
}

/// An access key interpreted by the containing menu's keyboard policy.
public enum MenuShortcut: Equatable, Sendable {
    /// The item's original position, numbered 1–9. Later items have no automatic key.
    case automatic
    /// A local access key, including Unicode. Menu bars also register Alt/Control variants for printable ASCII.
    case key(Character)
    case none
}

extension MenuItemDefinition {
    public var menuShortcut: MenuShortcut { .automatic }
}

/// Adapts typed choices to the engine's local string payloads. Highlight state retains
/// typed identity; positional payloads and access keys are rebuilt with the collection.
@MainActor
struct MenuCollection<Item: Identifiable> {
    let items: [Item]
    let menuItems: [MenuItem]

    init(
        items: [Item], global: Bool, title: (Item) -> String,
        shortcut: (Item) -> MenuShortcut, unavailableReason: (Item) -> String?
    ) {
        self.items = items
        menuItems = items.enumerated().map { index, item in
            let key: Character?
            switch shortcut(item) {
            case .automatic: key = index < 9 ? Character(String(index + 1)) : nil
            case .key(let character): key = character
            case .none: key = nil
            }
            return MenuItem(
                id: "@item:\(index)", title: title(item), shortcut: key,
                unavailableReason: unavailableReason(item),
                globalShortcuts: global ? key.map(Self.globalShortcuts) ?? [] : []
            )
        }
    }

    func identity(of item: Item) -> AnyHashable { AnyHashable(ViewID(item.id)) }

    func payload(for identity: AnyHashable?) -> String? {
        guard let index = items.firstIndex(where: { self.identity(of: $0) == identity }) else { return nil }
        return menuItems[index].id
    }

    func binding(_ selection: Binding<AnyHashable?>) -> Binding<String?> {
        var result = Binding<String?>(
            get: { payload(for: selection.wrappedValue) },
            set: { payload in
                selection.wrappedValue = menuItems.firstIndex(where: { $0.id == payload })
                    .map { identity(of: items[$0]) }
            }
        )
        result.tracksState = selection.tracksState
        return result
    }

    func addingActivation(to element: Element, onActivate: @escaping (Item) -> Void) -> Element {
        let ids = Dictionary(uniqueKeysWithValues: menuItems.map { ($0.id, "@menu-item:" + $0.id) })
        func mark(_ element: Element) -> Element {
            var value = element.replacingChildren(element.children.map(mark))
            value.localMenuActionIDs = ids
            return value
        }
        var value = mark(element)
        value.isCollectionMenu = true
        for (item, menuItem) in zip(items, menuItems) {
            value.behaviors.append(ElementBehavior(.activate, id: "@menu-item:" + menuItem.id) { _ in
                if menuItem.unavailableReason == nil { onActivate(item) }
            })
        }
        return value
    }

    private static func globalShortcuts(_ character: Character) -> [KeyEvent] {
        // Unicode access keys remain local; their implicit global variants cannot be decoded.
        guard KeyEvent.altCharacter(character).globalShortcut != nil else { return [] }
        let key = character.lowercased().first ?? character
        return [KeyEvent.altCharacter(key), .controlCharacter(key)].compactMap { $0.globalShortcut }
    }
}
