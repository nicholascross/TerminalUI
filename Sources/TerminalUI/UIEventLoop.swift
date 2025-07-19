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
        self.renderer = Renderer(rows: layout.mainAreaHeight, cols: cols)
        // On resize, update layout and renderer, then redraw
        Terminal.onResize = { [weak self] r, c in
            guard let self = self else { return }
            self.layout = Layout(rows: r, cols: c)
            self.renderer = Renderer(rows: self.layout.mainAreaHeight, cols: c)
            self.redraw()
        }
    }

    /// Start processing input events and updating the UI.
    public func run() throws {
        running = true
        try Terminal.enableRawMode()
        defer { try? Terminal.disableRawMode() }

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
        let lines = listWidget.render(height: layout.mainAreaHeight)
        renderer.render(lines: lines)

        // Draw input prompt on bottom line
        Terminal.moveCursor(row: layout.inputOffset + 1, col: 1)
        inputWidget.render()
    }
}
