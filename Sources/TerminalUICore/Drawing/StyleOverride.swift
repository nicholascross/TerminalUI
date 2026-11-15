/// Optional properties distinguish inheritance from an explicit terminal default or false attribute.
public struct StyleOverride: Equatable, Sendable {
    public var foreground: TextStyle.Color?
    public var background: TextStyle.Color?
    public var bold: Bool?
    public var dim: Bool?
    public var italic: Bool?
    public var underline: Bool?
    public var reversed: Bool?

    public init(foreground: TextStyle.Color? = nil, background: TextStyle.Color? = nil,
                bold: Bool? = nil, dim: Bool? = nil, italic: Bool? = nil,
                underline: Bool? = nil, reversed: Bool? = nil) {
        self.foreground = foreground; self.background = background; self.bold = bold
        self.dim = dim; self.italic = italic; self.underline = underline; self.reversed = reversed
    }

    public func applying(to style: TextStyle) -> TextStyle {
        var result = style
        if let foreground { result.foreground = foreground }
        if let background { result.background = background }
        if let bold { result.bold = bold }
        if let dim { result.dim = dim }
        if let italic { result.italic = italic }
        if let underline { result.underline = underline }
        if let reversed { result.reversed = reversed }
        return result
    }

    package func merging(_ other: Self) -> Self {
        .init(foreground: other.foreground ?? foreground, background: other.background ?? background,
              bold: other.bold ?? bold, dim: other.dim ?? dim, italic: other.italic ?? italic,
              underline: other.underline ?? underline, reversed: other.reversed ?? reversed)
    }
}
