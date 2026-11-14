import Foundation
import TerminalUICore

/// Produces terminal output for complete frames, with explicit commit after a successful write.
public struct FrameEncoder {
    private var committed: CellGrid?
    private var pending: CellGrid?
    private let styles: ANSIStyleEncoder

    public init(colorEnabled: Bool? = nil) {
        styles = ANSIStyleEncoder(capability: colorEnabled.map { $0 ? .ansi16 : .none } ?? .detect(),
                                  extendedAttributes: false)
    }

    public init(capability: ColorCapability, extendedAttributes: Bool = false) {
        styles = ANSIStyleEncoder(capability: capability, extendedAttributes: extendedAttributes)
    }

    /// A pending frame must be committed or discarded before preparing another frame.
    public mutating func prepare(_ frame: CellGrid) -> String {
        precondition(pending == nil, "Commit or discard the pending terminal frame first")
        pending = frame
        let previous = committed
        let sameSize = previous?.width == frame.width && previous?.height == frame.height
        var output = ""
        var currentStyle: TextStyle?
        for row in 0 ..< frame.height {
            var dirty = (0 ..< frame.width).map { !sameSize || frame[$0, row] != previous?[$0, row] }
            // Changing either half of a wide glyph must repaint its complete old and new footprint.
            for column in 0 ..< frame.width where dirty[column] {
                for grid in [previous, frame] {
                    guard let cell = grid?[column, row] else { continue }
                    if cell.width == 0, column > 0 { dirty[column - 1] = true }
                    if cell.width == 2, column + 1 < frame.width { dirty[column + 1] = true }
                }
            }
            var column = 0
            while column < frame.width {
                guard dirty[column] else { column += 1; continue }
                output += "\u{1B}[\(row + 1);\(column + 1)H"
                while column < frame.width, dirty[column] {
                    if let cell = frame[column, row], cell.width != 0 {
                        if currentStyle != cell.style {
                            output += styles.encode(cell.style)
                            currentStyle = cell.style
                        }
                        output += cell.grapheme
                    }
                    column += 1
                }
            }
        }
        if !output.isEmpty {
            // Cursor addressing cancels pending autowrap after a bottom-right write.
            output += "\u{1B}[0m\u{1B}[1;1H"
        }
        return output
    }

    public mutating func commit() {
        guard let pending else { return }
        committed = pending
        self.pending = nil
    }

    /// A partially written frame leaves the physical terminal state unknown.
    public mutating func discard() {
        pending = nil
        committed = nil
    }
}
