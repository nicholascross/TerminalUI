/// A terminal mouse report in zero-based character cells, or widget-local cells during widget dispatch.
public struct MouseEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case press, release, scrollUp, scrollDown
    }

    public enum Button: Equatable, Sendable {
        case primary, middle, secondary
    }

    public let kind: Kind
    public let column: Int
    public let row: Int
    public let button: Button
    public let shift: Bool
    public let alt: Bool
    public let control: Bool

    public init(
        _ kind: Kind,
        column: Int,
        row: Int,
        button: Button = .primary,
        shift: Bool = false,
        alt: Bool = false,
        control: Bool = false,
    ) {
        self.kind = kind
        self.column = column
        self.row = row
        self.button = button
        self.shift = shift
        self.alt = alt
        self.control = control
    }

    package func translated(column: Int, row: Int) -> Self {
        Self(kind, column: self.column - column, row: self.row - row, button: button,
             shift: shift, alt: alt, control: control)
    }
}
