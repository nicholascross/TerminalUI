public struct ListRow: Equatable, Sendable {
    public let id: String
    public let title: String
    /// Disabled rows remain selectable for inspection, but cannot submit the list.
    public let isEnabled: Bool
    /// Optional row-specific action for Enter and a completed primary click. Ordinary lists select on click.
    public let activationID: String?

    public init(id: String, title: String, isEnabled: Bool = true, activationID: String? = nil) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.activationID = activationID
    }

    package var displayTitle: String { isEnabled ? title : "[disabled] " + title }
}
