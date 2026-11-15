import TerminalUICore
import TerminalUIRuntime

/// Drives the real application runtime without acquiring a terminal.
@MainActor
public final class ApplicationHarness<Root: TerminalView> {
    private let app: TerminalApp<Root>
    public init(root: Root, configuration: TerminalConfiguration = .init(), theme: Theme = .init(), diagnostic: (@MainActor (String) -> Void)? = nil)
    {
        app = TerminalApp(root: root, configuration: configuration, theme: theme, diagnostic: diagnostic)
    }
    public var context: TerminalApplicationContext { app.context }
    public var focusedTarget: ScopedFocusTarget? { app.host.focusedTarget }
    public var metrics: ComponentMetrics { app.presentation.metrics }
    public var hasPendingUpdates: Bool { app.presentation.hasPendingUpdates }
    public func preview(width: Int = 80, height: Int = 24) -> [String] { app.preview(width: width, height: height) }
    public func send(_ key: KeyEvent) { app.host.handleInput(key, source: app.presentation) }
    public func send(_ event: TerminalEvent) { app.host.handleInput(event, source: app.presentation) }
    public func invalidate() { app.presentation.invalidate() }
    public func unmount() { app.presentation.unmount() }
    @discardableResult
    public func transaction<Result>(_ work: () throws -> Result) rethrows -> Result { try app.presentation.transaction(work) }
}
