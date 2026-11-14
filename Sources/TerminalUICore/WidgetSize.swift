/// A desired size measured in terminal cells.
public struct WidgetSize: Equatable, Sendable {
    public var width: Int
    public var height: Int
    public init(width: Int, height: Int) {
        self.width = max(0, min(4096, width))
        self.height = max(0, min(4096, height))
    }
}
