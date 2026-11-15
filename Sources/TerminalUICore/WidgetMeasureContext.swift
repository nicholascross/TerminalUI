/// The space offered to a custom widget during measurement.
public struct WidgetMeasureContext {
    public let width: Int
    public let theme: Theme
    public init(width: Int, theme: Theme) { self.width = width; self.theme = theme }
}
