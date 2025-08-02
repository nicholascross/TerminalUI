import Darwin.C
import Foundation

/// Main event loop to drive UI based on input and state.
@MainActor
public class UIEventLoop {
    private let terminal: Terminal
    private let input = TerminalInput()
    private var layout: LayoutNode
    private var widgets: [Widget]
    private var focusIndex: Int = 0
    private var renderer: Renderer
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
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.drawScheduled = false
            self.redraw()
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
        self.init(rows: rows, columns: columns, widgets: widgets, layout: root, terminal: terminal)
    }

    /// Initialize the event loop with a custom layout strategy.
    public init(
        rows: Int,
        columns: Int,
        widgets: [Widget],
        layout: LayoutNode,
        terminal: Terminal
    ) {
        self.terminal = terminal
        self.rows = rows
        self.columns = columns
        self.layout = layout
        self.layout.update(rows: rows, cols: columns)
        self.widgets = widgets
        // Start focus on the first interactive widget, if any
        focusIndex = widgets.firstIndex(where: { $0.isUserInteractive }) ?? 0
        renderer = Renderer(rows: rows, cols: columns, terminal: terminal)
        // On resize, debounce bursts and update layout and renderer without reallocating
        terminal.onResize = { [weak self] rows, columns in
            guard let self = self else { return }
            self.resizeTask?.cancel()
            self.resizeTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 33_000_000)
                guard !Task.isCancelled else { return }
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

        // Read input events asynchronously
        for try await event in input.events() {
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

    /// A hashable key for accumulating border-edge masks.
    private struct MaskKey: Hashable {
        let row: Int
        let col: Int
    }

    // OptionSet representing border-edge masks for box-drawing.
    private struct BorderMask: OptionSet {
        let rawValue: Int
        static let north = BorderMask(rawValue: 1)
        static let south = BorderMask(rawValue: 2)
        static let west = BorderMask(rawValue: 4)
        static let east = BorderMask(rawValue: 8)
    }

    private func redraw() {
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
        renderBorders(regions: regions)
        renderTitles(regions: regions)
        renderer.blit()
        // Position cursor for focused multi-line text-input widget
        if let textInputWidget = widgets[focusIndex] as? TextInputWidget {
            let contentRegion = regions[focusIndex].inset(by: 1)
            // Compute visible window based on scroll offset
            var offset = textInputWidget.scrollOffset
            if textInputWidget.cursorRow < offset {
                offset = textInputWidget.cursorRow
            }
            if textInputWidget.cursorRow >= offset + contentRegion.height {
                offset = textInputWidget.cursorRow - contentRegion.height + 1
            }
            // Compute row position
            let visRow = textInputWidget.cursorRow - offset
            let row = contentRegion.top + visRow + 1
            // Compute column position (account for prompt on first buffer line)
            let fullLines = textInputWidget.buffer.split(
                separator: "\n", omittingEmptySubsequences: false
            ).map(String.init)
            let rawLine = fullLines[textInputWidget.cursorRow]
            let beforeCursor = String(rawLine.prefix(textInputWidget.cursorCol))
            let cleaned = beforeCursor.replacingTabs()
            let prefix = textInputWidget.cursorRow == 0 ? textInputWidget.prompt.count : 0
            let col = contentRegion.left + prefix + cleaned.count + 1
            terminal.moveCursor(row: row, col: col)
            terminal.showCursor()
        }
        fflush(stdout)
    }

    /// Renders borders around widget regions with correct box-drawing characters.
    private func renderBorders(regions: [Region]) {
        let (masks, disabledKeys) = buildBorderMasks(for: regions)
        drawBorders(from: masks, disabledKeys: disabledKeys)
    }

    private func buildBorderMasks(for regions: [Region]) -> ([MaskKey: BorderMask], Set<MaskKey>) {
        var masks = [MaskKey: BorderMask]()
        var disabledKeys = Set<MaskKey>()
        for (index, region) in regions.enumerated() {
            let disabled = widgets[index].isDisabled
            let hidden = widgets[index].isBorderHidden
            if hidden { continue }
            if region.width == 1, region.height > 1 {
                markVerticalDivider(
                    region,
                    disabled: disabled,
                    in: &masks,
                    disabledKeys: &disabledKeys
                )
            } else if region.width > 1, region.height > 0 {
                markPaneBorder(region, disabled: disabled, in: &masks, disabledKeys: &disabledKeys)
            }
        }
        return (masks, disabledKeys)
    }

    private func markVerticalDivider(
        _ region: Region,
        disabled: Bool,
        in masks: inout [MaskKey: BorderMask],
        disabledKeys: inout Set<MaskKey>
    ) {
        for row in region.top ..< region.top + region.height {
            let key = MaskKey(row: row, col: region.left)
            masks[key, default: []].insert([.north, .south])
            if disabled { disabledKeys.insert(key) }
        }
    }

    private func markPaneBorder(
        _ region: Region,
        disabled: Bool,
        in masks: inout [MaskKey: BorderMask],
        disabledKeys: inout Set<MaskKey>
    ) {
        let top = region.top
        let bottom = top + region.height - 1
        let left = region.left
        let right = left + region.width - 1

        for col in (left + 1) ..< right {
            let topKey = MaskKey(row: top, col: col)
            masks[topKey, default: []].insert([.east, .west])
            if disabled { disabledKeys.insert(topKey) }
            let bottomKey = MaskKey(row: bottom, col: col)
            masks[bottomKey, default: []].insert([.east, .west])
            if disabled { disabledKeys.insert(bottomKey) }
        }
        for row in (top + 1) ..< bottom {
            let leftKey = MaskKey(row: row, col: left)
            masks[leftKey, default: []].insert([.north, .south])
            if disabled { disabledKeys.insert(leftKey) }
            let rightKey = MaskKey(row: row, col: right)
            masks[rightKey, default: []].insert([.north, .south])
            if disabled { disabledKeys.insert(rightKey) }
        }
        let tl = MaskKey(row: top, col: left)
        masks[tl, default: []].insert([.south, .east]); if disabled { disabledKeys.insert(tl) }

        let tr = MaskKey(row: top, col: right)
        masks[tr, default: []].insert([.south, .west]); if disabled { disabledKeys.insert(tr) }

        let bl = MaskKey(row: bottom, col: left)
        masks[bl, default: []].insert([.north, .east]); if disabled { disabledKeys.insert(bl) }

        let br = MaskKey(row: bottom, col: right)
        masks[br, default: []].insert([.north, .west]); if disabled { disabledKeys.insert(br) }
    }

    private func drawBorders(
        from masks: [MaskKey: BorderMask],
        disabledKeys: Set<MaskKey>
    ) {
        for (key, mask) in masks {
            let char = boxCharacter(for: mask)
            let style: Style = disabledKeys.contains(key) ? .gray : []
            renderer.setCell(row: key.row, col: key.col, char: char, style: style)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func boxCharacter(for mask: BorderMask) -> Character {
        switch mask {
        case [.north, .south, .west, .east]: return "┼"
        case [.south, .west, .east]: return "┬"
        case [.north, .west, .east]: return "┴"
        case [.north, .south, .east]: return "├"
        case [.north, .south, .west]: return "┤"
        case [.north, .south]: return "│"
        case [.west, .east]: return "─"
        case [.south, .east]: return "┌"
        case [.south, .west]: return "┐"
        case [.north, .east]: return "└"
        case [.north, .west]: return "┘"
        default:
            return mask.isDisjoint(with: [.north, .south]) ? "─" : "│"
        }
    }

    /// Draws widget titles over top borders, indicating focus and interactivity.
    private func renderTitles(regions: [Region]) {
        for index in widgets.indices {
            let widget = widgets[index]
            let region = regions[index]
            let maxLen = max(0, region.width - 2)
            var titleText: String?
            if let title = widget.title {
                if widget.isUserInteractive, index == focusIndex {
                    titleText = "[\(title)]"
                } else {
                    titleText = " \(title) "
                }
            } else if widget.isUserInteractive, index == focusIndex {
                titleText = "[*]"
            }
            if let text = titleText {
                let textToDraw = String(text.prefix(maxLen))
                let startCol = region.left + 1
                let row = region.top
                for (offset, char) in textToDraw.enumerated() {
                    renderer.setCell(row: row, col: startCol + offset, char: char)
                }
            }
        }
    }
}
