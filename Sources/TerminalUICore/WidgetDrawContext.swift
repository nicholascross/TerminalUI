/// Drawing information for a custom widget's clipped canvas.
public struct WidgetDrawContext {
    public let size: WidgetSize
    public let focused: Bool
    public let theme: Theme
    /// Resolved element style, including inherited and local overrides.
    public let style: TextStyle
    public let enabled: Bool
    public init(size: WidgetSize, focused: Bool, theme: Theme, style: TextStyle? = nil, enabled: Bool = true) {
        self.size = size; self.focused = focused; self.theme = theme
        self.style = style ?? theme.normal; self.enabled = enabled
    }
}
