/// Space placed around an element, measured in terminal cells.
public struct Insets: Equatable, Sendable {
    public let top: Int
    public let leading: Int
    public let bottom: Int
    public let trailing: Int

    public init(top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0) {
        self.top = max(0, min(4096, top))
        self.leading = max(0, min(4096, leading))
        self.bottom = max(0, min(4096, bottom))
        self.trailing = max(0, min(4096, trailing))
    }

    public static func all(_ amount: Int) -> Self {
        .init(top: amount, leading: amount, bottom: amount, trailing: amount)
    }
}
