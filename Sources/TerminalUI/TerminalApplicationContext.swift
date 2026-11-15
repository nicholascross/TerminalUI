import TerminalUIComponentRuntime
import TerminalUICore

/// Services for the presentation containing a mounted component. Retaining a context does not retain the application.
@MainActor
public struct TerminalApplicationContext {
    private weak var services: (any ApplicationServices)?

    package init(services: any ApplicationServices) {
        self.services = services
    }

    /// Current host or preview dimensions in cells. Reads in a view subscribe it to size changes.
    /// Dimensions are zero until the host supplies a size or after the application is released.
    public var terminalSize: TerminalSize {
        services?.terminalSize ?? TerminalSize(columns: 0, rows: 0)
    }

    /// Finds a control through a path of view IDs or ForEach item IDs.
    /// Unidentified views are transparent; each identified subtree needs a path entry.
    public func focusTarget(path: [AnyHashable] = [], id: String) -> ScopedFocusTarget? {
        services?.focusTarget(path: path, id: id)
    }

    /// Resolves a value registered by a control's `.focusTarget(value)` modifier.
    /// Use a mounted scope to distinguish repeated values in independent workspaces.
    public func focusTarget<Value: Hashable>(_ value: Value, in scope: ViewScope? = nil) -> ScopedFocusTarget? {
        services?.focusTarget(value: ViewID(value), in: scope)
    }

    /// The registered value for actual focus. Reads in a view subscribe that view to focus changes.
    /// Returns nil outside the requested type or mounted scope; this is not a writable focus mirror.
    public func focusedValue<Value: Hashable>(of type: Value.Type, in scope: ViewScope? = nil) -> Value? {
        services?.focusedValue(of: ObjectIdentifier(type), in: scope)?.base as? Value
    }

    /// Focuses a registered typed target, respecting visibility, availability and modal boundaries.
    @discardableResult
    public func focus<Value: Hashable>(_ value: Value, in scope: ViewScope? = nil) -> Bool {
        guard let target = focusTarget(value, in: scope) else { return false }
        return focus(target)
    }

    @discardableResult
    public func focus(_ target: ScopedFocusTarget) -> Bool {
        services?.focus(target) ?? false
    }

    public func keepVisible(_ target: ScopedFocusTarget) {
        services?.keepVisible(target)
    }

    public func scope<ID: Hashable>(_ id: ID, in parent: ViewScope? = nil) -> ViewScope? {
        services?.scope(id: AnyHashable(ViewID(id)), in: parent)
    }

    /// Finds a control through view/item IDs relative to a named scope.
    public func focusTarget(path: [AnyHashable] = [], id: String, in scope: ViewScope) -> ScopedFocusTarget? {
        services?.focusTarget(path: path, id: id, in: scope)
    }

    @discardableResult
    public func reveal<ID: Hashable>(_ id: ID, in scope: ViewScope? = nil) -> Bool {
        services?.reveal(id: AnyHashable(ViewID(id)), in: scope) ?? false
    }

    public func stop() {
        services?.stop()
    }
}
