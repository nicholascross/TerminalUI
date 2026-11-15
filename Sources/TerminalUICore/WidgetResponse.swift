/// The result of dispatching a key to a custom widget.
public enum WidgetResponse: Sendable {
    case unhandled
    case consumed
    case action(UIAction)
}
