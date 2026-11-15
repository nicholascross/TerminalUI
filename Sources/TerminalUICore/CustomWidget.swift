/// An advanced control rendered into its own clipped canvas.
/// Business values remain the application's responsibility, as with built-in controls.
public protocol CustomWidget {
    var id: String? { get }
    var isFocusable: Bool { get }
    func measure(context: WidgetMeasureContext) -> WidgetSize
    func draw(in canvas: inout Canvas, context: WidgetDrawContext)
    func respond(to key: KeyEvent, context: WidgetEventContext) -> WidgetResponse
    /// Mouse positions are local to the assigned content canvas. Releases require a matching press target.
    func respond(to mouse: MouseEvent, context: WidgetMouseContext) -> WidgetResponse
    /// A stable item identity for matching press/release, or nil for noninteractive cells. Defaults to the widget ID.
    func mouseTarget(at mouse: MouseEvent, context: WidgetMouseContext) -> String?
    /// Desired dimensions for a proposed width, in cells.
    func measure(width: Int) -> WidgetSize
    func draw(in canvas: inout Canvas, focused: Bool)
    func draw(in canvas: inout Canvas, focused: Bool, theme: Theme)
    /// Return an action for a consumed key, or nil if it was not consumed.
    func handle(_ key: KeyEvent) -> UIAction?
    /// Distinguishes a consumed key with no action from an unhandled key.
    func respond(to key: KeyEvent, theme: Theme) -> WidgetResponse
}

public extension CustomWidget {
    func respond(to mouse: MouseEvent, context: WidgetMouseContext) -> WidgetResponse { .unhandled }
    func mouseTarget(at mouse: MouseEvent, context: WidgetMouseContext) -> String? { id }
    var isFocusable: Bool { false }
    func measure(width: Int) -> WidgetSize { WidgetSize(width: 0, height: 0) }
    func draw(in canvas: inout Canvas, focused: Bool) {}
    func measure(context: WidgetMeasureContext) -> WidgetSize { measure(width: context.width) }
    func draw(in canvas: inout Canvas, context: WidgetDrawContext) {
        draw(in: &canvas, focused: context.focused, theme: context.theme)
    }
    func respond(to key: KeyEvent, context: WidgetEventContext) -> WidgetResponse {
        respond(to: key, theme: context.theme)
    }
    func handle(_ key: KeyEvent) -> UIAction? { nil }
    func respond(to key: KeyEvent, theme: Theme) -> WidgetResponse {
        handle(key).map { .action($0) } ?? .unhandled
    }
    func draw(in canvas: inout Canvas, focused: Bool, theme: Theme) {
        draw(in: &canvas, focused: focused)
    }
}
