import Darwin.C
import Foundation

/// Result builder that lets you declare Widgets inline in your layout DSL.
/// Widgets are collected in declaration order, and each is replaced by a WidgetLeaf internally.
@resultBuilder
public enum UIBuilder {
    private static var widgets: [Widget] = []

    /// Reset the collected widget buffer. Called automatically at the start of building.
    static func resetWidgets() {
        widgets = []
    }

    /// The widgets collected during the most recent build.
    public static var collectedWidgets: [Widget] { widgets }

    /// Wrap a raw Widget: record it and emit the corresponding leaf node.
    public static func buildExpression(_ widget: Widget) -> WidgetLeaf {
        let idx = widgets.count
        widgets.append(widget)
        return WidgetLeaf(idx)
    }

    /// Pass through any existing LayoutNode (e.g. Stack, Sized, WidgetLeaf).
    public static func buildExpression(_ node: any LayoutNode) -> any LayoutNode {
        return node
    }

    /// Combine multiple nodes into the root array.
    public static func buildBlock(_ nodes: any LayoutNode...) -> [any LayoutNode] {
        return nodes
    }
}

// Allow calling `.frame(width:height:)` directly on Widgets within the UIBuilder DSL.
public extension Widget {
    /// Record this widget in UIBuilder and wrap it in a fixed-size leaf.
    func frame(width: Int? = nil, height: Int? = nil) -> Sized<WidgetLeaf> {
        let leaf = UIBuilder.buildExpression(self)
        return leaf.frame(width: width, height: height)
    }
}

/// Main event loop to drive UI based on input and state.
public class UIEventLoop {
    private let input = TerminalInput()
    private var layout: LayoutNode
    private var widgets: [Widget]
    private var focusIndex: Int = 0
    private var renderer: Renderer
    private var rows: Int
    private var columns: Int
    private var running = false

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
    /// try loop.run()
    /// ```
    public convenience init(
        @UIBuilder _ build: () -> [any LayoutNode]
    ) {
        // Collect inline widgets in declaration order
        UIBuilder.resetWidgets()
        let roots = build()
        let widgets = UIBuilder.collectedWidgets
        guard let root = roots.first else {
            fatalError("UIBuilder must produce at least one root layout node")
        }
        let (rows, columns) = Terminal.getTerminalSize()
        self.init(rows: rows, columns: columns, widgets: widgets, layout: root)
    }

    /// Initialize the event loop with a custom layout strategy.
    public init(
        rows: Int,
        columns: Int,
        widgets: [Widget],
        layout: LayoutNode
    ) {
        self.rows = rows
        self.columns = columns
        self.layout = layout
        self.layout.update(rows: rows, cols: columns)
        self.widgets = widgets
        // Start focus on the first interactive widget, if any
        self.focusIndex = widgets.firstIndex(where: { $0.isUserInteractive }) ?? 0
        renderer = Renderer(rows: rows, cols: columns)
        // On resize, update layout and renderer, then redraw
        Terminal.onResize = { [weak self] rows, columns in
            guard let self = self else { return }
            self.rows = rows
            self.columns = columns
            self.layout.update(rows: rows, cols: columns)
            self.renderer = Renderer(rows: rows, cols: columns)
            // Clear screen on resize to avoid leftover artifacts
            Terminal.clearScreen()
            self.redraw()
        }
    }

    /// Start processing input events and updating the UI.
    public func run() throws {
        running = true
        try Terminal.enableRawMode()
        defer {
            try? Terminal.disableRawMode()
            Terminal.showCursor()
        }

        // Clear screen and perform initial draw
        Terminal.clearScreen()
        redraw()
        // Batch paste events: only redraw once between paste start/end markers
        var inPaste = false
        do {
            while running {
                let event = try input.readEvent()
                switch event {
                case .pasteStart:
                    inPaste = true
                case .pasteEnd:
                    inPaste = false
                    redraw()
                // 'q' quits only outside of a paste; during a paste literal 'q's go into the buffer
                case .char("q") where !inPaste, .ctrlC:
                    running = false
                case .tab:
                    var next = focusIndex
                    repeat {
                        next = (next + 1) % widgets.count
                    } while !widgets[next].isUserInteractive && next != focusIndex
                    focusIndex = next
                    if !inPaste { redraw() }
                default:
                    let widget = widgets[focusIndex]
                    if let textInputWidget = widget as? TextInputWidget {
                        if let line = textInputWidget.handle(event: event) {
                            if let list = widgets.first(where: { $0 is ListWidget }) as? ListWidget {
                                list.items.append(line)
                            }
                        }
                    } else {
                        _ = widget.handle(event: event)
                    }
                    if !inPaste { redraw() }
                }
            }
        } catch {
            fputs("Input error: \(error)\n", stderr)
        }
    }

    /// A hashable key for accumulating border-edge masks.
    private struct MaskKey: Hashable {
        let row: Int
        let col: Int
    }

    private func redraw() {
        Terminal.hideCursor()
        renderer.clearBuffer()
        let container = Region(top: 0, left: 0, width: columns, height: rows)
        let regions = layout.regions(for: widgets.count, in: container)
        // If the available terminal is too small for fixed frames, show warning
        let (minWidth, minHeight) = layout.minimalSize(widgetCount: widgets.count)
        if columns < minWidth || rows < minHeight {
            Terminal.clearScreen()
            Terminal.moveCursor(row: 1, col: 1)
            print("Screen too small: current=\(columns)x\(rows), minimum=\(minWidth)x\(minHeight)")
            fflush(stdout)
            return
        }
        // Ensure each widget has at least a 1×1 content region
        for (idx, region) in regions.enumerated() {
            let contentRegion = region.inset(by: 1)
            if contentRegion.width <= 0 || contentRegion.height <= 0 {
                Terminal.clearScreen()
                Terminal.moveCursor(row: 1, col: 1)
                let sizeInfo = "(got \(contentRegion.width)x\(contentRegion.height))"
                print("Screen too small: widget #\(idx) needs at least 1×1 content area \(sizeInfo)")
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
            // Determine current line index and buffer lines
            let lines = textInputWidget.buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let lineIndex = min(lines.count - 1, contentRegion.height - 1)
            // Row and column within content region (plus legacy offset)
            let row = contentRegion.top + lineIndex + 1
            let prefix = lineIndex == 0 ? textInputWidget.prompt.count : 0
            let col = contentRegion.left + prefix + lines[lineIndex].count + 1
            Terminal.moveCursor(row: row, col: col)
            Terminal.showCursor()
        }
        fflush(stdout)
    }

    /// Renders borders around widget regions with correct box-drawing characters.
    private func renderBorders(regions: [Region]) {
        let northMask = 1, southMask = 2, westMask = 4, eastMask = 8
        var masks = [MaskKey: Int]()
        for region in regions {
            if region.width == 1, region.height > 1 {
                // vertical divider (explicit widget): mark north/south edges
                for rowIndex in region.top ..< region.top + region.height {
                    masks[MaskKey(row: rowIndex, col: region.left), default: 0] |= northMask | southMask
                }
            } else if region.width > 1, region.height > 0 {
                // pane border: mark top/bottom (east/west) and left/right (north/south)
                let top = region.top
                let left = region.left
                let bottom = region.top + region.height - 1
                let right = region.left + region.width - 1
                for colIndex in (left + 1) ..< right {
                    masks[MaskKey(row: top, col: colIndex), default: 0] |= eastMask | westMask
                    masks[MaskKey(row: bottom, col: colIndex), default: 0] |= eastMask | westMask
                }
                for rowIndex in (top + 1) ..< bottom {
                    masks[MaskKey(row: rowIndex, col: left), default: 0] |= northMask | southMask
                    masks[MaskKey(row: rowIndex, col: right), default: 0] |= northMask | southMask
                }
                // mark corners to render corner characters
                masks[MaskKey(row: top, col: left), default: 0] |= southMask | eastMask
                masks[MaskKey(row: top, col: right), default: 0] |= southMask | westMask
                masks[MaskKey(row: bottom, col: left), default: 0] |= northMask | eastMask
                masks[MaskKey(row: bottom, col: right), default: 0] |= northMask | westMask
            }
        }
        // Render merged borders with proper box-drawing joins
        for (key, mask) in masks {
            let row = key.row, col = key.col
            let char: Character = {
                switch mask {
                case northMask | southMask | eastMask | westMask: return "┼"
                case southMask | eastMask | westMask: return "┬"
                case northMask | eastMask | westMask: return "┴"
                case northMask | southMask | eastMask: return "├"
                case northMask | southMask | westMask: return "┤"
                case northMask | southMask: return "│"
                case eastMask | westMask: return "─"
                case southMask | eastMask: return "┌"
                case southMask | westMask: return "┐"
                case northMask | eastMask: return "└"
                case northMask | westMask: return "┘"
                default: return mask & (northMask | southMask) != 0 ? "│" : "─"
                }
            }()
            renderer.setCell(row: row, col: col, char: char)
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
                if widget.isUserInteractive && index == focusIndex {
                    titleText = "[\(title)]"
                } else {
                    titleText = " \(title) "
                }
            } else if widget.isUserInteractive && index == focusIndex {
                titleText = "*"
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
