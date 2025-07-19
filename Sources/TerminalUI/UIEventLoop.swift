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
    private var cols: Int
    private var running = false

    /// Initialize the event loop with a custom layout strategy.
    public init(
        rows: Int,
        cols: Int,
        widgets: [Widget],
        layout: LayoutNode
) {
        self.rows = rows
        self.cols = cols
        self.layout = layout
        self.layout.update(rows: rows, cols: cols)
        self.widgets = widgets
        self.renderer = Renderer(rows: rows, cols: cols)
        // On resize, update layout and renderer, then redraw
        Terminal.onResize = { [weak self] r, c in
            guard let self = self else { return }
            self.rows = r
            self.cols = c
            self.layout.update(rows: r, cols: c)
            self.renderer = Renderer(rows: r, cols: c)
            self.redraw()
        }
    }

    /// Convenience initializer using the default absolute Layout.
    public convenience init(
        rows: Int,
        cols: Int,
        widgets: [Widget]
    ) {
        self.init(rows: rows, cols: cols, widgets: widgets,
                  layout: Layout(rows: rows, cols: cols))
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
        Terminal.hideCursor()
        renderer.clearBuffer()
        let container = Region(top: 0, left: 0, width: cols, height: rows)
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
                // horizontal divider
                for x in region.left..<(region.left + region.width) {
                    renderer.setCell(row: region.top, col: x, char: "─")
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
