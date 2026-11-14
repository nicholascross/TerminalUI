/// A grapheme's leading cell or its continuation cell.
public struct Cell: Equatable, Sendable {
    public internal(set) var grapheme: String
    /// Zero denotes the continuation of a wide grapheme.
    public internal(set) var width: Int
    public internal(set) var style: TextStyle

    internal static let blank = Cell(grapheme: " ", width: 1, style: TextStyle())
}
