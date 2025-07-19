import Foundation
import Darwin.C

/// Main event loop to drive UI based on input and state.
public class UIEventLoop {
    private let input = Input()
    private var layout: Layout
    public var listWidget: ListWidget
    private var inputWidget: TextInputWidget
    private var renderer: Renderer
    private var running = false
    private enum Focus { case list, input }
    private var focus: Focus = .input

    public init(rows: Int, cols: Int) {
        self.layout = Layout(rows: rows, cols: cols)
        self.listWidget = ListWidget(items: [])
        self.inputWidget = TextInputWidget(prompt: "> ")
        self.renderer = Renderer(rows: rows, cols: cols)
        // On resize, update layout and renderer, then redraw
        Terminal.onResize = { [weak self] r, c in
            guard let self = self else { return }
            self.layout = Layout(rows: r, cols: c)
            self.renderer = Renderer(rows: r, cols: c)
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
                // Toggle focus between list and input
                focus = (focus == .input ? .list : .input)
                redraw()
            default:
                switch focus {
                case .input:
                    if let line = inputWidget.handle(event: event) {
                        listWidget.items.append(line)
                    }
                case .list:
                    _ = listWidget.handle(event: event)
                }
                redraw()
            }
        }
    }

    private func redraw() {
        Terminal.hideCursor()
        renderer.clearBuffer()
        // Main list: inset by 1 row/col under the main border.
        let mainBorder = layout.mainRegion
        let mainContent = Region(
            top: mainBorder.top + 1,
            left: mainBorder.left + 1,
            width: max(mainBorder.width - 2, 0),
            height: max(mainBorder.height - 2, 0)
        )
        listWidget.render(into: renderer, region: mainContent)

        // Input box content: inset by 1 row/col under its border.
        let inputBorder = layout.inputRegion
        let inputContent = Region(
            top: inputBorder.top + 1,
            left: inputBorder.left + 1,
            width: max(inputBorder.width - 2, 0),
            height: 1
        )
        inputWidget.render(into: renderer, region: inputContent)

        // Draw borders around main list and input box.
        renderer.drawBorder(mainBorder)
        renderer.drawBorder(inputBorder)
        renderer.blit()
        // Position and show the cursor at end of input buffer inside the input box.
        let col = inputContent.left + 1 + (inputWidget.prompt + inputWidget.buffer).count
        let row = inputContent.top + 1
        Terminal.moveCursor(row: row, col: col)
        Terminal.showCursor()
        fflush(stdout)
    }
}
