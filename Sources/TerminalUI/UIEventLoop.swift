import Darwin.C
import Foundation

/// Main event loop to drive UI based on input and state.
public class UIEventLoop {
    private let input = Input()
    private var layout: LayoutNode
    private var widgets: [Widget]
    private var focusIndex: Int = 0
    private var renderer: Renderer
    private var rows: Int
    private var columns: Int
    private var running = false

    public convenience init(
        widgets: [Widget],
        layout: LayoutNode
    ) {
        let (rows, columns) = Terminal.getTerminalSize()
        self.init(rows: rows, columns: columns, widgets: widgets, layout: layout)
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
        renderer = Renderer(rows: rows, cols: columns)
        // On resize, update layout and renderer, then redraw
        Terminal.onResize = { [weak self] rows, columns in
            guard let self = self else { return }
            self.rows = rows
            self.columns = columns
            self.layout.update(rows: rows, cols: columns)
            self.renderer = Renderer(rows: rows, cols: columns)
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

        // Initial draw
        redraw()
        while running {
            let event = try input.readEvent()
            switch event {
            case .char("q"), .ctrlC:
                running = false
            case .tab:
                focusIndex = (focusIndex + 1) % widgets.count
                redraw()
            default:
                let widget = widgets[focusIndex]
                if let ti = widget as? TextInputWidget {
                    if let line = ti.handle(event: event) {
                        if let list = widgets.first(where: { $0 is ListWidget }) as? ListWidget {
                            list.items.append(line)
                        }
                    }
                } else {
                    _ = widget.handle(event: event)
                }
                redraw()
            }
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
        for (widget, region) in zip(widgets, regions) {
            // Render widget content inset by 1 cell so top row isn't under the border
            let contentRegion = region.inset(by: 1)
            widget.render(into: renderer, region: contentRegion)
        }
        // Build a unified border mask to render shared joins correctly
        let N = 1, S = 2, W = 4, E = 8
        var masks = [MaskKey: Int]()
        for region in regions {
            if region.width == 1, region.height > 1 {
                // vertical divider: mark north/south edges
                for y in region.top ..< (region.top + region.height) {
                    masks[MaskKey(row: y, col: region.left), default: 0] |= N | S
                }
            } else if region.width > 1, region.height > 0 {
                // pane border: top/bottom (E/W) and left/right (N/S), clamped to screen
                let top = max(region.top - 1, 0)
                let left = max(region.left - 1, 0)
                let bottom = min(region.top + region.height, rows - 1)
                let right = min(region.left + region.width, columns - 1)
                for x in (left + 1) ..< right {
                    masks[MaskKey(row: top, col: x), default: 0] |= E | W
                    masks[MaskKey(row: bottom, col: x), default: 0] |= E | W
                }
                for y in (top + 1) ..< bottom {
                    masks[MaskKey(row: y, col: left), default: 0] |= N | S
                    masks[MaskKey(row: y, col: right), default: 0] |= N | S
                }
                // mark corners to render corner characters
                masks[MaskKey(row: top, col: left), default: 0] |= S | E
                masks[MaskKey(row: top, col: right), default: 0] |= S | W
                masks[MaskKey(row: bottom, col: left), default: 0] |= N | E
                masks[MaskKey(row: bottom, col: right), default: 0] |= N | W
            }
        }
        // Render merged borders with proper box-drawing joins
        for (key, mask) in masks {
            let row = key.row, col = key.col
            let ch: Character = {
                switch mask {
                case N | S | E | W: return "┼"
                case S | E | W: return "┬"
                case N | E | W: return "┴"
                case N | S | E: return "├"
                case N | S | W: return "┤"
                case N | S: return "│"
                case E | W: return "─"
                case S | E: return "┌"
                case S | W: return "┐"
                case N | E: return "└"
                case N | W: return "┘"
                default: return mask & (N | S) != 0 ? "│" : "─"
                }
            }()
            renderer.setCell(row: row, col: col, char: ch)
        }
        renderer.blit()
        // Position cursor for focused text-input widget
        if let ti = widgets[focusIndex] as? TextInputWidget {
            // Position cursor inside the boxed content (inset by 1)
            let contentRegion = regions[focusIndex].inset(by: 1)
            let row = contentRegion.top + 1
            let col = contentRegion.left + (ti.prompt + ti.buffer).count + 1
            Terminal.moveCursor(row: row, col: col)
            Terminal.showCursor()
        }
        fflush(stdout)
    }
}
