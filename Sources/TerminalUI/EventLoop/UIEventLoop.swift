import Darwin.C
import Foundation

/// Main event loop to drive UI based on input and state.
@MainActor
public class UIEventLoop {
    private let terminal: Terminal
    private let inputSource: InputEventSource
    private var layout: LayoutNode
    private var widgets: [Widget]
    private var focusIndex: Int = 0
    private let renderer: EventLoopRenderer
    private var rows: Int
    private var columns: Int
    private var running = false

    /// Flag to coalesce redraw requests.
    private var drawScheduled = false

    /// Pending resize task to debounce terminal resize events.
    private var resizeTask: Task<Void, Never>?

    /// Schedule a redraw asynchronously, coalescing multiple calls.
    private func invalidate() {
        guard !drawScheduled else { return }
        drawScheduled = true

        Task.detached { [weak self] in
            guard let self = self else { return }
            // Debounce redraw to coalesce multiple invalidate calls
            try? await Task.sleep(nanoseconds: 16_000_000)
            // redraw will reset drawScheduled
            await self.redraw()
        }
    }

    /// Closure invoked when an event is not handled by the focused widget.
    /// Use this to provide global handling of unhandled events.
    public var onUnhandledEvent: ((InputEvent) -> Void)?

    /// Async task driving periodic ticks via ContinuousClock.sleep.
    private var tickTask: Task<Void, Never>?
    private let clock = ContinuousClock()
    private var tickInterval: Duration = .milliseconds(100)
    private var inPaste = false // make it a stored property, not a local var

    /// Start the async task driving periodic ticks via ContinuousClock.sleep.
    private func startTicks() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            guard let self = self else { return }
            var last = self.clock.now
            while !Task.isCancelled && self.running {
                // --- tick work ---
                let now = self.clock.now
                let delta = now - last
                last = now
                var invalidated = false
                for widget in self.widgets {
                    if widget.handle(event: .tick(dt: delta)) { invalidated = true }
                }
                if invalidated {
                    await MainActor.run { self.invalidate() }
                }

                // --- schedule next ---
                let interval = self.inPaste ? self.tickInterval * 2 : self.tickInterval
                try? await self.clock.sleep(
                    until: now.advanced(by: interval),
                    tolerance: .milliseconds(8)
                )
            }
        }
    }

    /// Cancel the tick-driving async task.
    private func stopTicks() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// Build a UIEventLoop by declaring widgets inline in the layout DSL.
    ///
    /// Example:
    /// ```swift
    /// let loop = UIEventLoop {
    ///   Stack(axis: .vertical, spacing: 1) {
    ///     headerWidget.frame(height: 3)
    ///     ListWidget(items: [...]).frame(width: 20)
    ///     // inline widgets automatically collected
    ///   }
    /// }
    /// try await loop.run()
    /// ```
    public convenience init(
        terminal: Terminal = Terminal(),
        @UIBuilder _ build: () -> [any LayoutNode]
    ) {
        // Collect inline widgets in declaration order
        UIBuilder.resetWidgets()
        let roots = build()
        let widgets = UIBuilder.collectedWidgets
        guard let root = roots.first else {
            fatalError("UIBuilder must produce at least one root layout node")
        }
        let (rows, columns) = terminal.getTerminalSize()
        let renderer = Renderer(rows: rows, cols: columns, terminal: terminal)
        let inputSource = TerminalInput()
        self.init(
            rows: rows,
            columns: columns,
            widgets: widgets,
            layout: root,
            terminal: terminal,
            renderer: renderer,
            inputSource: inputSource
        )
    }

    /// Initialize the event loop with a custom layout strategy.
    /// Initialize the event loop with a custom layout strategy and injected dependencies.
    public init(
        rows: Int,
        columns: Int,
        widgets: [Widget],
        layout: LayoutNode,
        terminal: Terminal,
        renderer: EventLoopRenderer,
        inputSource: InputEventSource
    ) {
        self.terminal = terminal
        self.rows = rows
        self.columns = columns
        self.layout = layout
        self.layout.update(rows: rows, cols: columns)
        self.widgets = widgets
        // Start focus on the first interactive widget, if any
        focusIndex = widgets.firstIndex(where: { $0.isUserInteractive }) ?? 0
        // Dependencies are injected to facilitate testing
        self.renderer = renderer
        self.inputSource = inputSource

        terminal.onResize = { [weak self] rows, columns in
            guard let self = self else { return }
            self.resizeTask?.cancel()
            self.resizeTask = Task { @MainActor in
                self.rows = rows
                self.columns = columns
                self.layout.update(rows: rows, cols: columns)
                self.renderer.resize(rows: rows, cols: columns)
                self.terminal.clearScreen()
                self.invalidate()
            }
        }
    }

    /// Start processing input events, driving animation ticks and updating the UI.
    public func run() async throws {
        running = true
        try terminal.enableRawMode()
        defer {
            try? terminal.disableRawMode()
            terminal.showCursor()
        }

        // Initial draw
        terminal.clearScreen()
        redraw()

        // Drive periodic ticks asynchronously
        startTicks()

        // Read input events asynchronously from injected source
        for try await event in inputSource.events() {
            handle(event: event)
            if !running { break }
        }

        stopTicks()
    }

    private func handle(event: InputEvent) {
        switch event {
        case .pasteStart:
            inPaste = true

        case .pasteEnd:
            inPaste = false
            invalidate()

        case .char("q") where !inPaste, .ctrlC:
            running = false

        case .tab:
            focusNextWidget()
            if !inPaste { invalidate() }

        default:
            dispatchEventToCurrentWidget(event)
        }
    }

    private func focusNextWidget() {
        var next = focusIndex
        repeat {
            next = (next + 1) % widgets.count
        } while !widgets[next].isUserInteractive && next != focusIndex
        focusIndex = next
    }

    private func dispatchEventToCurrentWidget(_ event: InputEvent) {
        let widget = widgets[focusIndex]
        // Only treat the event as handled if widget.handle(event:) returns true
        let didHandle = !widget.isDisabled && widget.handle(event: event)
        if !didHandle {
            onUnhandledEvent?(event)
        }
        // Redraw only when widget state changed (e.g. spinner advanced)
        if didHandle, !inPaste {
            invalidate()
        }
    }

    private func redraw() {
        drawScheduled = false
        terminal.hideCursor()
        renderer.clearBuffer()
        let container = Region(top: 0, left: 0, width: columns, height: rows)
        let regions = layout.regions(for: widgets.count, in: container)
        // If the available terminal is too small for fixed frames, show warning
        let (minWidth, minHeight) = layout.minimalSize(widgetCount: widgets.count)
        if columns < minWidth || rows < minHeight {
            terminal.clearScreen()
            terminal.moveCursor(row: 1, col: 1)
            print("Screen too small: current=\(columns)x\(rows), minimum=\(minWidth)x\(minHeight)")
            fflush(stdout)
            return
        }
        // Ensure each widget has at least a 1×1 content region
        for (idx, region) in regions.enumerated() {
            let contentRegion = region.inset(by: 1)
            if contentRegion.width <= 0 || contentRegion.height <= 0 {
                terminal.clearScreen()
                terminal.moveCursor(row: 1, col: 1)
                let sizeInfo = "(got \(contentRegion.width)x\(contentRegion.height))"
                print(
                    "Screen too small: widget #\(idx) needs at least 1×1 content area \(sizeInfo)"
                )
                fflush(stdout)
                return
            }
        }
        for (widget, region) in zip(widgets, regions) {
            // Render widget content inset by 1 cell so top row isn't under the border
            let contentRegion = region.inset(by: 1)
            widget.render(into: renderer, region: contentRegion)
        }
        renderer.drawBorders(regions: regions, widgets: widgets)
        renderer.drawTitles(regions: regions, widgets: widgets, focusIndex: focusIndex)
        renderer.blit()
        // Position cursor for focused widget if it provides one
        let contentRegion = regions[focusIndex].inset(by: 1)
        if let (row, col) = widgets[focusIndex].cursorPosition(in: contentRegion) {
            terminal.moveCursor(row: row, col: col)
            terminal.showCursor()
        }
        fflush(stdout)
    }
}
