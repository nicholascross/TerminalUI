/// An application-owned section in a tab strip. IDs must be unique within the strip.
public struct Tab: Equatable, Sendable {
    public let id: String
    public let title: String
    public init(id: String, title: String) { self.id = id; self.title = title }
}
