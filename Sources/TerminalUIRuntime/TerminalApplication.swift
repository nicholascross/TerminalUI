import TerminalUICore

/// An application owns its model and applies actions synchronously before the next view is built.
@MainActor
public protocol TerminalApplication: AnyObject {
    func view() -> Element
    func handle(_ action: UIAction)
}
