/// Context supplied when a focused custom widget handles a key.
public struct WidgetEventContext {
    public let focused: Bool
    public let theme: Theme
    public init(focused: Bool, theme: Theme) { self.focused = focused; self.theme = theme }
}
