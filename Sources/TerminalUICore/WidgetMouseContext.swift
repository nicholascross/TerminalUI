/// Geometry and appearance for a custom widget receiving local mouse coordinates.
public struct WidgetMouseContext {
    public let size: WidgetSize
    public let focused: Bool
    public let theme: Theme

    public init(size: WidgetSize, focused: Bool, theme: Theme) {
        self.size = size
        self.focused = focused
        self.theme = theme
    }
}
