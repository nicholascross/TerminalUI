import Foundation
import TerminalUIComponentRuntime
import TerminalUICore

/// An optional presentation source and terminal-independent component harness.
@MainActor
public final class ComponentApplication: TerminalPresentationSource {
    public typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Void
    private let runtime: ComponentRuntime
    private let legacy: (any TerminalApplication)?
    private let fallback: (UIAction) -> Void
    private var services = PresentationServices()
    private var invalidated = false

    isolated deinit { runtime.unmount() }

    public var hasPendingUpdates: Bool {
        invalidated || runtime.hasPendingUpdates
    }

    public var revision: UInt64 {
        runtime.revision
    }

    public var metrics: ComponentMetrics {
        runtime.metrics
    }

    public init(
        root: some TerminalView,
        onAction: @escaping (UIAction) -> Void = { _ in },
        schedule: @escaping Scheduler = ComponentApplication.scheduleUpdate,
        diagnostic: @escaping @MainActor (String) -> Void = ComponentApplication.reportDiagnostic,
    ) {
        legacy = nil; fallback = onAction
        runtime = ComponentRuntime(makeRoot: { Component(root) }, schedule: schedule, diagnostic: diagnostic)
    }

    /// Rebuilds the legacy view only for explicit invalidation or an unclaimed action.
    public init(
        legacy: any TerminalApplication,
        schedule: @escaping Scheduler = ComponentApplication.scheduleUpdate,
        diagnostic: @escaping @MainActor (String) -> Void = ComponentApplication.reportDiagnostic,
    ) {
        self.legacy = legacy; fallback = { _ in }
        runtime = ComponentRuntime(makeRoot: { legacy.view() }, schedule: schedule, diagnostic: diagnostic)
    }

    public func connect(_ services: PresentationServices) {
        self.services = services
        runtime.connect(services)
    }

    @discardableResult
    public func resolve(invalidateRoot: Bool = false) -> Element {
        if runtime.driver.transactionDepth > 0 { return runtime.resolve() }
        let force = invalidateRoot || invalidated
        invalidated = false
        return runtime.resolve(invalidateRoot: force)
    }

    public func handle(_ action: UIAction) {
        if runtime.handle(action) { return }
        let original = runtime.unscoped(action)
        if let legacy { legacy.handle(original) } else { fallback(original) }
        invalidate()
    }

    public func invalidate() {
        invalidated = true
        runtime.driver.requestFlush()
    }

    /// Writes take effect immediately; resolution/output waits until the outermost scope exits.
    @discardableResult
    public func transaction<Result>(_ work: () throws -> Result) rethrows -> Result {
        try runtime.driver.transaction(work)
    }

    /// `path` lists explicit component keys from the root. Ordinary reveal IDs are separate.
    public func focusTarget(path: [AnyHashable] = [], id: String) -> ScopedFocusTarget? {
        _ = resolve()
        return runtime.focusTarget(path: path, id: id)
    }

    public func focusTarget(key: AnyHashable, id: String) -> ScopedFocusTarget? {
        focusTarget(path: [key], id: id)
    }

    @discardableResult
    public func focus(_ target: ScopedFocusTarget) -> Bool {
        services.focus(target.engineID, resolve())
    }

    public func keepVisible(_ target: ScopedFocusTarget) {
        services.reveal(target.engineID)
    }

    /// Ends the generation explicitly, useful when a harness/root is being reused.
    public func unmount() {
        runtime.unmount()
    }

    public static func scheduleUpdate(_ flush: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            await Task.yield()
            flush()
        }
    }

    public static func reportDiagnostic(_ message: String) {
        #if DEBUG
            FileHandle.standardError.write(Data("TerminalUIComponents: \(message)\n".utf8))
        #endif
    }
}
