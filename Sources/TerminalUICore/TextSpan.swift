/// A run of paragraph text with a semantic theme role.
public struct TextSpan: Sendable {
    public var text: String
    public var style: StyleOverride
    public var role: TextRole

    public init(_ text: String, role: TextRole = .normal, style: StyleOverride = .init()) {
        self.text = text
        self.role = role
        self.style = style
    }
}
