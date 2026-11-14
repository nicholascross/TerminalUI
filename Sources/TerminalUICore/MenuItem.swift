/// An action in a menu. IDs must be unique within the menu.
public struct MenuItem: Equatable, Sendable {
    public let id: String
    public let title: String
    public let shortcut: Character?
    /// Opt-in shortcuts active throughout this menu's dialog or workspace scope.
    /// Supports Alt/Control characters and the dedicated Control-C/D/P keys.
    /// Plain typing, paste, Tab and Escape never become global menu shortcuts.
    public let globalShortcuts: [KeyEvent]
    /// Unavailable items remain selectable so their prerequisite can be inspected.
    public let unavailableReason: String?

    public init(id: String, title: String, shortcut: Character? = nil, unavailableReason: String? = nil,
                globalShortcuts: [KeyEvent] = []) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
        self.globalShortcuts = globalShortcuts
        self.unavailableReason = unavailableReason
    }
}
