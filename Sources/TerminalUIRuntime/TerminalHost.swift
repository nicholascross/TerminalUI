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
    }

    /// The control currently receiving keyboard input.
    public var focusedID: String? {
        engine.focusedID
    }

    /// Focuses a control in the current view, keeping it visible in enclosing scroll views.
    @discardableResult
    public func focus(_ id: String, in root: Element) -> Bool {
        let result = engine.focus(id, in: root)
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
        invalidate()
    }

    /// Requests an orderly shutdown. It is safe to call repeatedly.
    public func stop() {
        stopped = true
    }

    private func currentView(_ application: any TerminalApplication) -> Element {
        if !needsViewRebuild, let retainedRoot { return retainedRoot }
        needsViewRebuild = false
        let root = application.view()
        retainedRoot = root
        engine.updateTree(root)
        return root
    }

    /// Shared by the terminal loop and terminal-independent interaction tests.
    func renderIfNeeded(_ application: any TerminalApplication, size: TerminalSize) -> CellGrid? {
        inputSize = size
        guard needsRepaint, size.columns > 0, size.rows > 0 else { return nil }
        needsRepaint = false
        _ = currentView(application)
        return engine.repaintGrid(width: size.columns, height: size.rows)
    }

    func handleInput(_ event: KeyEvent, application: any TerminalApplication) {
        let result = engine.handleEvent(event, in: currentView(application))
        needsRepaint = true
        switch result {
        case .repaint: break
        case let .rebuild(action):
            invalidate()
            if let action { deliver(action, to: application) }
        }
    }

    func handleInput(_ event: TerminalEvent, application: any TerminalApplication) {
        switch event {
        case let .key(key): handleInput(key, application: application)
        case let .mouse(mouse):
            guard configuration.mouseEnabled, let size = inputSize, size.columns > 0, size.rows > 0 else { return }
            _ = currentView(application)
            // Actions and wheel input can change geometry within a single terminal read.
            // Prepare it without consuming the pending output frame.
            engine.prepareMouseInput(width: size.columns, height: size.rows)
            let result = engine.handleMouseEvent(mouse)
            needsRepaint = true
            if case let .rebuild(action) = result {
                invalidate()
                if let action { deliver(action, to: application) }
            }
        }
    }

    func deliver(_ action: UIAction, to application: any TerminalApplication) {
        if case let .resized(size) = action { inputSize = size }
        application.handle(action)
        invalidate()
    }

    /// Acquires the controlling TTY and runs until stopped, cancelled, disconnected, or signalled.
    /// The host temporarily installs process-wide signal handlers and restores them when it exits.
    public func run(_ application: any TerminalApplication) async throws {
        guard !running, !Self.sessionActive else { throw TerminalError.sessionAlreadyActive }
        guard ProcessInfo.processInfo.environment["TERM"] != "dumb" else { throw TerminalError.unsupportedTerminal }
        running = true
        Self.sessionActive = true
        stopped = false
        invalidate()
        defer { running = false; Self.sessionActive = false }
        let session = try TerminalSession(configuration: configuration)
        defer { session.restore() }
        var decoder = InputDecoder(pasteLimit: configuration.pasteLimit)
        let encoder = FrameEncoder(capability: configuration.colorCapability ?? .detect(),
                                   extendedAttributes: configuration.extendedAttributes)
        var output = TerminalFrameWriter(encoder: encoder) { bytes in
            try await Task.detached { try session.writeAll(bytes) }.value
        }
        var size = try session.size()
        deliver(.resized(size), to: application)
        var escapeDeadline = EscapeDeadline(clock: ContinuousClock(), milliseconds: configuration.escapeTimeoutMilliseconds)

        while !stopped, !Task.isCancelled {
            if let grid = renderIfNeeded(application, size: size) {
                try await output.writeFrame(grid)
            }
            let timeout = escapeDeadline.pollTimeout
            let input = try await Task.detached { try session.readInput(timeout: timeout) }.value
            if input.terminate || input.endOfFile { break }
            let newSize = try session.size()
            if newSize != size {
                size = newSize
                deliver(.resized(size), to: application)
            }
            // Escape and incomplete escape sequences are resolved on an idle deadline.
            if !input.bytes.isEmpty {
                escapeDeadline.receivedInput()
                let events = decoder.feedEvents(input.bytes)
                for event in events {
                    handleInput(event, application: application)
                }
                for _ in 0 ..< decoder.completedTruncatedPastes {
                    deliver(.pasteTruncated, to: application)
                }
            } else if escapeDeadline.consumeIfExpired() {
                for event in decoder.flushEscape() {
                    handleInput(event, application: application)
                }
            }
        }
    }
}
