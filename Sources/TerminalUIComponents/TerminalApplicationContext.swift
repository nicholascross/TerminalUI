import TerminalUIComponentRuntime
import TerminalUICore

/// Services for the presentation containing a mounted component. Retaining a context does not retain the application.
@MainActor
public struct TerminalApplicationContext {
    private weak var services: (any ApplicationServices)?

    package init(services: any ApplicationServices) {
        self.services = services
    }

    public func focusTarget(path: [AnyHashable] = [], id: String) -> ScopedFocusTarget? {
        services?.focusTarget(path: path, id: id)
    }

    @discardableResult
    public func focus(_ target: ScopedFocusTarget) -> Bool {
        services?.focus(target) ?? false
    }

    public func keepVisible(_ target: ScopedFocusTarget) {
        services?.keepVisible(target)
    }

    public func stop() {
        services?.stop()
    }
}
