import TerminalUI

@main
struct App {
    static func main() throws {
        let (rows, cols) = Terminal.getTerminalSize()
        Terminal.clearScreen()
        defer {
            Terminal.showCursor()
            Terminal.clearScreen()
        }

        // Print resize events
        Terminal.onResize = { rows, cols in
            Terminal.clearScreen()
            Terminal.moveCursor(row: 1, col: 1)
            print("Resized to \(rows)x\(cols)")
        }

        // Build dynamic widget set
        let list = ListWidget(items: ["Item A", "Item B", "Item C"])
        let textArea = TextAreaWidget(lines: [
            "Line 1: Hello, World!",
            "Line 2: This is a text area.",
            "Line 3: Use ↑/↓ to scroll.",
            "Line 4: Swift TerminalUI",
            "Line 5: Enjoy!"
        ])
        let input = TextInputWidget(prompt: "> ")
        let widgets: [Widget] = [list, textArea, input]
        // Choose layout strategy: default absolute or constraint-based when --constraint flag is passed
        let loop: UIEventLoop
        if CommandLine.arguments.contains("--constraint") {
            // Arrange widgets with explicit constraints
            var layout = ConstraintLayout(rows: rows, cols: cols)
            // widget 0: top-left block (inset for border)
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(0, .left),
                    .equal,
                    nil,
                    constant: 1
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(0, .top),
                    .equal,
                    nil,
                    constant: 1
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(0, .width),
                    .equal,
                    nil,
                    constant: cols/2 - 2
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(0, .height),
                    .equal,
                    nil,
                    constant: rows - 5
                )
            )
            // widget 1: right block
            // widget 1: top-right block (inset for border)
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(1, .left),
                    .equal,
                    nil,
                    constant: cols/2 + 1
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(1, .top),
                    .equal,
                    nil,
                    constant: 1
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(1, .width),
                    .equal,
                    nil,
                    constant: cols/2 - 2
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(1, .height),
                    .equal,
                    nil,
                    constant: rows - 5
                )
            )
            // widget 2: input bar at bottom
            // widget 2: input bar at bottom (1-line interior)
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(2, .left),
                    .equal,
                    nil,
                    constant: 1
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(2, .top),
                    .equal,
                    nil,
                    constant: rows - 2
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(2, .width),
                    .equal,
                    nil,
                    constant: cols - 2
                )
            )
            layout.addConstraint(
                ConstraintLayout.Constraint(
                    ConstraintLayout.Anchor(2, .height),
                    .equal,
                    nil,
                    constant: 1
                )
            )
            loop = UIEventLoop(rows: rows, cols: cols, widgets: widgets, layout: layout)
        } else {
            loop = UIEventLoop(rows: rows, cols: cols, widgets: widgets)
        }
        try loop.run()
    }
}
