/// Describes whether input can repaint the retained tree or needs a fresh application view.
public enum UIEventResult: Equatable, Sendable {
    /// Built-in viewport navigation with unchanged focus can reuse the current tree.
    case repaint
    /// Other input conservatively requests a fresh application view.
    case rebuild(action: UIAction?)

    public var action: UIAction? {
        if case let .rebuild(action) = self { return action }
        return nil
    }
}
