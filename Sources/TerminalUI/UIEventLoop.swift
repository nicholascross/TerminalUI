import Foundation
import Darwin.C

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
        self.renderer = Renderer(rows: rows, cols: columns)
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

    private func redraw() {
        Terminal.hideCursor()
        renderer.clearBuffer()
        let container = Region(top: 0, left: 0, width: columns, height: rows)
        let regions = layout.regions(for: widgets.count, in: container)
        for (widget, region) in zip(widgets, regions) {
            widget.render(into: renderer, region: region)
        }
        for region in regions {
            // Divider regions (1-cell thick): draw single lines
            if region.width == 1 && region.height > 1 {
                // vertical divider
                for y in region.top..<(region.top + region.height) {
                    renderer.setCell(row: y, col: region.left, char: "│")
                }
            } else if region.height == 1 && region.width > 1 {
                // horizontal borders for single-line region (top and bottom)
                for x in region.left..<(region.left + region.width) {
                    renderer.setCell(row: region.top - 1, col: x, char: "─")
                    renderer.setCell(row: region.top + 1, col: x, char: "─")
                }
            } else if region.width > 1 && region.height > 1 {
                // normal bordered pane (undo the 1-cell inset)
                let border = Region(top: region.top - 1,
                                    left: region.left - 1,
                                    width: region.width + 2,
                                    height: region.height + 2)
                renderer.drawBorder(border)
            }
        }
        renderer.blit()
        // Position cursor for focused text-input widget
        if let ti = widgets[focusIndex] as? TextInputWidget {
            let region = regions[focusIndex]
            let col = region.left + (ti.prompt + ti.buffer).count + 1
            let row = region.top + 1
            Terminal.moveCursor(row: row, col: col)
            Terminal.showCursor()
        }
        fflush(stdout)
    }
}
