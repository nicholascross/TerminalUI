/// A table column with a fixed cell width or a weighted share of remaining space.
public struct TableColumn: Equatable, Sendable {
    public let title: String
    public let width: LayoutSize
    public init(_ title: String, width: LayoutSize = .fill()) {
        self.title = title
        self.width = width
    }
}
