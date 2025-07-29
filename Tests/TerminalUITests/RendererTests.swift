import Foundation
import Testing
@testable import TerminalUI

@Suite("Renderer", .serialized)
struct RendererTests {
    /// A simple in-memory text output stream for capturing terminal output.
    private class StringStream: TextOutputStream {
        var content = ""
        func write(_ string: String) {
            content += string
        }
    }

    /// Capture terminal output during the block using the TextOutputStream abstraction.
    private func captureOutput(renderer: Renderer, _ block: () -> Void) -> String {
        let stream = StringStream()
        let original = renderer.terminal.output
        renderer.terminal.output = stream
        defer { renderer.terminal.output = original }

        block()
        return stream.content
    }

    @Test
    func narrowCharPrintsAllCells() {
        let renderer = Renderer(rows: 1, cols: 3)
        renderer.setCell(row: 0, col: 0, char: "a")
        renderer.setCell(row: 0, col: 1, char: "b")
        renderer.setCell(row: 0, col: 2, char: "c")
        let output = captureOutput(renderer: renderer) { renderer.blit() }
        // Strip ANSI escape sequences (cursor moves and styles)
        let cleaned = output.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "",
            options: .regularExpression
        )
        #expect(cleaned == "abc")
    }

    @Test
    func wideCharSkipsCells() {
        let renderer = Renderer(rows: 1, cols: 3)
        renderer.setCell(row: 0, col: 0, char: "x")
        renderer.setCell(row: 0, col: 1, char: "👍")
        renderer.setCell(row: 0, col: 2, char: "y")
        let output = captureOutput(renderer: renderer) { renderer.blit() }
        let cleaned = output.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "",
            options: .regularExpression
        )
        #expect(cleaned == "x👍")
    }

    @Test
    func terminalColumnWidthIsCorrect() {
        #expect(Character("a").terminalColumnWidth == 1)
        #expect(Character("👍").terminalColumnWidth == 2)
    }
}
