import Foundation

/// A generic UI widget that can render itself and handle events.
public protocol Widget {
    /// Optional title displayed over the top border of the widget.
    var title: String? { get set }
    /// Renders the widget into the given region.
    func render(into renderer: Renderer, region: Region)

    /// Handles an input event. Returns true if the event produced an actionable result.
    func handle(event: InputEvent) -> Bool
}
