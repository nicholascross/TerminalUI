/// An application-owned table row. IDs must be unique within the table.
public struct TableRow: Equatable, Sendable {
    public let id: String
    public let cells: [String]
    public init(id: String, cells: [String]) { self.id = id; self.cells = cells }
}
