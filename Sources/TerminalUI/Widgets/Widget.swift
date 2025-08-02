import Foundation

/// A generic UI widget that can render itself and handle events.
public protocol Widget {
    /// Optional title displayed over the top border of the widget.
    var title: String? { get set }
    /// Indicates whether the widget is user interactive (focusable and handles input events).
    var isUserInteractive: Bool { get }
    /// Renders the widget into the given region.
    func render(into renderer: Renderer, region: Region)

    /// Handles an input event. Returns true if the event produced an actionable result.
    func handle(event: InputEvent) -> Bool
    /// Indicates whether the widget is disabled (focusable but does not receive input events).
    var isDisabled: Bool { get set }
}

public extension Widget {
    /// Default non-interactive behavior for widgets.
    var isUserInteractive: Bool { return false }
    /// Default disabled state (widgets are enabled by default).
    var isDisabled: Bool { get { false } set { } }
}
