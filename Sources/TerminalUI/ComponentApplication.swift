import Foundation
import TerminalUIComponentRuntime
import TerminalUICore

/// An optional presentation source and terminal-independent component harness.
@MainActor
package final class ComponentApplication: TerminalPresentationSource {
    package typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Void
    private let runtime: ComponentRuntime
    private let legacy: (any TerminalApplication)?
    private let fallback: (UIAction) -> Void
    private var services = PresentationServices()
    private var invalidated = false

    isolated deinit { runtime.unmount() }

    package var hasPendingUpdates: Bool {
        invalidated || runtime.hasPendingUpdates
    }

    package var revision: UInt64 {
        runtime.revision
    }

    package var metrics: ComponentMetrics {
        runtime.metrics
    }

    package init(
        root: some TerminalView,
        onAction: @escaping (UIAction) -> Void = { _ in },
        schedule: @escaping Scheduler = ComponentApplication.scheduleUpdate,
        diagnostic: @escaping @MainActor (String) -> Void = ComponentApplication.reportDiagnostic,
    ) {
        legacy = nil
        fallback = onAction
        runtime = ComponentRuntime(makeRoot: { rootElement(lowerView(root)) }, schedule: schedule, diagnostic: diagnostic)
        runtime.driver.applicationServices = self
    }

    /// Rebuilds the legacy view only for explicit invalidation or an unclaimed action.
    package init(
        legacy: any TerminalApplication,
        schedule: @escaping Scheduler = ComponentApplication.scheduleUpdate,
        diagnostic: @escaping @MainActor (String) -> Void = ComponentApplication.reportDiagnostic,
    ) {
        self.legacy = legacy
        fallback = { _ in }
        runtime = ComponentRuntime(makeRoot: { legacy.view() }, schedule: schedule, diagnostic: diagnostic)
        runtime.driver.applicationServices = self
    }

    package func connect(_ services: PresentationServices) {
        self.services = services
        runtime.connect(services)
    }

    @discardableResult
    package func resolve(invalidateRoot: Bool = false) -> Element {
        if runtime.driver.transactionDepth > 0 { return runtime.resolve() }
        let force = invalidateRoot || invalidated
        invalidated = false
        return runtime.resolve(invalidateRoot: force)
    }

    package func focusDidChange(_ target: ScopedFocusTarget?) {
        runtime.focusDidChange(target)
    }

    package func handle(_ action: UIAction) {
        if runtime.handle(action) { return }
        let original = runtime.unscoped(action)
        if let legacy { legacy.handle(original) } else { fallback(original) }
        invalidate()
    }

    package func invalidate() {
        invalidated = true
        runtime.driver.requestFlush()
    }

    /// Writes take effect immediately; resolution/output waits until the outermost scope exits.
    @discardableResult
    package func transaction<Result>(_ work: () throws -> Result) rethrows -> Result {
        try runtime.driver.transaction(work)
    }

    /// `path` lists explicit component keys from the root. Ordinary reveal IDs are separate.
    package func focusTarget(path: [AnyHashable] = [], id: String) -> ScopedFocusTarget? {
        _ = resolve()
        return runtime.focusTarget(path: path, id: id)
    }

    package func focusTarget(key: AnyHashable, id: String) -> ScopedFocusTarget? {
        focusTarget(path: [key], id: id)
    }

    @discardableResult
    package func focus(_ target: ScopedFocusTarget) -> Bool {
        services.focus(target.engineID, resolve())
    }

    package func keepVisible(_ target: ScopedFocusTarget) {
        services.reveal(target.engineID)
    }

    package func scope(id: AnyHashable, in parent: ViewScope?) -> ViewScope? {
        _ = resolve()
        return runtime.scope(id: id, in: parent)
    }

    package func focusTarget(path: [AnyHashable], id: String, in scope: ViewScope?) -> ScopedFocusTarget? {
        _ = resolve()
        return runtime.focusTarget(path: path, id: id, in: scope)
    }

    package func reveal(id: AnyHashable, in scope: ViewScope?) -> Bool {
        _ = resolve()
        guard let address = runtime.revealTarget(id: id, in: scope) else { return false }
        services.reveal(address)
        return true
    }

    package var context: TerminalApplicationContext { TerminalApplicationContext(services: self) }

    package func stop() { services.stop() }

    /// Ends the generation explicitly, useful when a harness/root is being reused.
    package func unmount() {
        runtime.unmount()
    }

    package static func scheduleUpdate(_ flush: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await Task.yield()
            flush()
        }
    }

    package static func reportDiagnostic(_ message: String) {
        #if DEBUG
            FileHandle.standardError.write(Data("TerminalUI: \(message)\n".utf8))
        #endif
    }
}

extension ComponentApplication: ApplicationServices {}
