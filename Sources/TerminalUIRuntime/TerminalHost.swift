import Foundation
import TerminalUICore
import TerminalUIInput
import TerminalUIRendering

/// Hosts one component tree on the controlling terminal. Calls into the application occur on the main actor.
@MainActor
public final class TerminalHost {
    private static var sessionActive = false
    private let configuration: TerminalConfiguration
    private let engine: UIEngine
    private var needsRepaint = true
    private var needsViewRebuild = true
    private var retainedRoot: Element?
    private var stopped = false
    private var running = false
    private var inputSize: TerminalSize?
    private var legacySource: LegacyApplicationPresentation?
    private var legacyID: ObjectIdentifier?
    private var sourceID: ObjectIdentifier?
    private weak var activeSource: (any TerminalPresentationSource)?
    private var lastNotifiedFocus: ScopedFocusTarget?
    private var sourceRevision: UInt64?
    private var updateWakeup: ApplicationUpdateWakeup?
    public private(set) var frameWriteCount = 0

    private func presentation(_ application: any TerminalApplication) -> LegacyApplicationPresentation {
        if legacyID != ObjectIdentifier(application) {
            legacyID = ObjectIdentifier(application)
            legacySource = LegacyApplicationPresentation(application)
        }
        return legacySource!
    }

    public init(configuration: TerminalConfiguration = .init(), theme: Theme = .init()) {
        self.configuration = configuration
        engine = UIEngine(theme: theme)
    }

    /// Allows interaction tests to share the engine used by programmatic focus requests.
    init(configuration: TerminalConfiguration = .init(), engine: UIEngine) {
        self.configuration = configuration
        self.engine = engine
    }

    /// Changes the active theme and schedules a redraw.
    public var theme: Theme {
        get { engine.theme }
        set { engine.theme = newValue; invalidate() }
    }

    /// Requests a redraw after application-owned state changes. Calls are coalesced.
    public func invalidate() {
        needsRepaint = true; needsViewRebuild = true
        updateWakeup?.signal()
    }

    /// The control currently receiving keyboard input.
    public var focusedID: String? {
        engine.focusedID
    }

    /// The current focus as an opaque handle, suitable for comparing scoped component targets.
    public var focusedTarget: ScopedFocusTarget? {
        engine.focusedID.map { ScopedFocusTarget(engineID: $0) }
    }

    private func publishFocus(to source: any TerminalPresentationSource) {
        let target = focusedTarget
        guard lastNotifiedFocus != target else { return }
        lastNotifiedFocus = target
        source.focusDidChange(target)
    }

    /// Focuses a control in the current view, keeping it visible in enclosing scroll views.
    @discardableResult
    public func focus(_ id: String, in root: Element) -> Bool {
        let result = engine.focus(id, in: root)
        if let activeSource { publishFocus(to: activeSource) }
        if result { invalidate() }
        return result
    }

    /// Reveals identified content in its enclosing scroll views on the next render.
    public func keepVisible(_ id: String) {
        engine.keepVisible(id); invalidate()
    }

    /// Clears transient widget state before reusing an ID for a different semantic value.
    public func resetState(for id: String) {
        engine.resetState(for: id)
        if let activeSource { publishFocus(to: activeSource) }
        invalidate()
    }

    /// Requests an orderly shutdown. It is safe to call repeatedly.
    public func stop() {
        stopped = true
        updateWakeup?.signal()
    }

    /// Connects presentation services without acquiring a TTY or evaluating the root.
    public func connect(_ source: any TerminalPresentationSource) {
        if sourceID != ObjectIdentifier(source) {
            sourceID = ObjectIdentifier(source)
            sourceRevision = nil
            lastNotifiedFocus = nil
            needsViewRebuild = true
        }
        activeSource = source
        source.connect(PresentationServices(requestUpdate: { [weak self] in
            self?.needsRepaint = true
            self?.updateWakeup?.signal()
        }, focus: { [weak self, weak source] id, root in
            guard let self, let source else { return false }
            let focused = self.engine.focus(id, in: root)
            self.publishFocus(to: source)
            if focused { self.needsRepaint = true; self.updateWakeup?.signal() }
            return focused
        }, reveal: { [weak self] id in
            self?.engine.keepVisible(id)
            self?.needsRepaint = true
            self?.updateWakeup?.signal()
        }, stop: { [weak self] in
            self?.stop()
        }))
    }

    /// Resolves a frame using the host's focus and theme without acquiring a TTY.
    public func preview(_ source: any TerminalPresentationSource, width: Int = 80, height: Int = 24) -> [String] {
        inputSize = TerminalSize(columns: width, rows: height)
        _ = currentView(source)
        return engine.repaintGrid(width: width, height: height).lines
    }

    private func currentView(_ source: any TerminalPresentationSource) -> Element {
        connect(source)
        var root = source.resolve(invalidateRoot: needsViewRebuild)
        needsViewRebuild = false
        while true {
            if sourceRevision != source.revision {
                sourceRevision = source.revision
                retainedRoot = root
                engine.updateTree(root)
            }
            publishFocus(to: source)
            guard source.hasPendingUpdates else { return root }
            // Focus feedback can dirty component state. Resolve it before dispatch or painting.
            let previousRevision = source.revision
            root = source.resolve(invalidateRoot: false)
            // A transaction can deliberately defer resolution until its outermost scope exits.
            if source.revision == previousRevision { return root }
        }
    }

    /// Shared by the terminal loop and terminal-independent interaction tests.
    func renderIfNeeded(_ application: any TerminalApplication, size: TerminalSize) -> CellGrid? {
        renderIfNeeded(presentation(application), size: size)
    }

    func renderIfNeeded(_ source: any TerminalPresentationSource, size: TerminalSize) -> CellGrid? {
        inputSize = size
        guard needsRepaint || source.hasPendingUpdates, size.columns > 0, size.rows > 0 else { return nil }
        _ = currentView(source)
        needsRepaint = false
        return engine.repaintGrid(width: size.columns, height: size.rows)
    }

    func handleInput(_ event: KeyEvent, application: any TerminalApplication) {
        handleInput(event, source: presentation(application))
    }

    func handleInput(_ event: KeyEvent, source: any TerminalPresentationSource) {
        let result = engine.handleEvent(event, in: currentView(source))
        publishFocus(to: source)
        needsRepaint = true
        if case let .rebuild(action) = result {
            if let action { deliver(action, to: source) } else { invalidate() }
        }
    }

    func handleInput(_ event: TerminalEvent, application: any TerminalApplication) {
        handleInput(event, source: presentation(application))
    }

    func handleInput(_ event: TerminalEvent, source: any TerminalPresentationSource) {
        switch event {
        case let .key(key): handleInput(key, source: source)
        case let .mouse(mouse):
            guard configuration.mouseEnabled, let size = inputSize, size.columns > 0, size.rows > 0 else { return }
            _ = currentView(source)
            // Resolve effects and geometry before the next pointer event in the same input read.
            engine.prepareMouseInput(width: size.columns, height: size.rows)
            let result = engine.handleMouseEvent(mouse)
            publishFocus(to: source)
            needsRepaint = true
            if case let .rebuild(action) = result {
                if let action { deliver(action, to: source) } else { invalidate() }
            }
        }
    }

    func deliver(_ action: UIAction, to application: any TerminalApplication) {
        deliver(action, to: presentation(application))
    }

    func deliver(_ action: UIAction, to source: any TerminalPresentationSource) {
        if case let .resized(size) = action { inputSize = size }
        source.handle(action)
        needsRepaint = true
    }

    @discardableResult
    public func focus(_ target: ScopedFocusTarget, in source: any TerminalPresentationSource) -> Bool {
        let result = engine.focus(target.engineID, in: currentView(source))
        publishFocus(to: source)
        if result { needsRepaint = true; updateWakeup?.signal() }
        return result
    }

    public func run(_ application: any TerminalApplication) async throws {
        try await run(presentation(application))
    }

    /// Acquires the controlling TTY and runs until stopped, cancelled, disconnected, or signalled.
    /// The host temporarily installs process-wide signal handlers and restores them when it exits.
    public func run(_ source: any TerminalPresentationSource) async throws {
        guard !running, !Self.sessionActive else { throw TerminalError.sessionAlreadyActive }
        guard ProcessInfo.processInfo.environment["TERM"] != "dumb" else { throw TerminalError.unsupportedTerminal }
        running = true
        Self.sessionActive = true
        stopped = false
        invalidate()
        defer { running = false; Self.sessionActive = false }
        let session = try TerminalSession(configuration: configuration)
        defer { session.restore() }
        let wakeup = try ApplicationUpdateWakeup()
        updateWakeup = wakeup
        defer { updateWakeup = nil; wakeup.finish() }
        var decoder = InputDecoder(pasteLimit: configuration.pasteLimit)
        let encoder = FrameEncoder(capability: configuration.colorCapability ?? .detect(),
                                   extendedAttributes: configuration.extendedAttributes)
        var output = TerminalFrameWriter(encoder: encoder) { bytes in
            try await Task.detached { try session.writeAll(bytes) }.value
        }
        var size = try session.size()
        deliver(.resized(size), to: source)
        var escapeDeadline = EscapeDeadline(clock: ContinuousClock(), milliseconds: configuration.escapeTimeoutMilliseconds)

        while !stopped, !Task.isCancelled {
            if let grid = renderIfNeeded(source, size: size) {
                try await output.writeFrame(grid)
                frameWriteCount += 1
            }
            let timeout = escapeDeadline.pollTimeout
            // Await the reader even on cancellation before restoring/closing any descriptors.
            let input = try await withTaskCancellationHandler {
                try await Task.detached { try session.readInput(timeout: timeout, updateDescriptor: wakeup.descriptor) }.value
            } onCancel: { wakeup.signal() }
            wakeup.drain()
            if input.terminate || input.endOfFile { break }
            let newSize = try session.size()
            if newSize != size {
                size = newSize
                deliver(.resized(size), to: source)
            }
            // Escape and incomplete escape sequences are resolved on an idle deadline.
            if !input.bytes.isEmpty {
                escapeDeadline.receivedInput()
                let events = decoder.feedEvents(input.bytes)
                for event in events {
                    handleInput(event, source: source)
                }
                for _ in 0 ..< decoder.completedTruncatedPastes {
                    deliver(.pasteTruncated, to: source)
                }
            } else if escapeDeadline.consumeIfExpired() {
                for event in decoder.flushEscape() {
                    handleInput(event, source: source)
                }
            }
        }
    }
}
