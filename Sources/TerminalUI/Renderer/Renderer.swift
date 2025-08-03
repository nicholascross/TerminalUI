import Darwin.C
import Foundation

/// Manages a virtual screen buffer and rendering to terminal.
public class Renderer {
    private var buffer: [[Cell]]
    /// Last drawn buffer state used for diff redraws.
    private var lastBuffer: [[Cell]]

    /// Initialize renderer with given dimensions and terminal.
    public let terminal: Terminal

    public init(rows: Int, cols: Int, terminal: Terminal = Terminal()) {
        self.terminal = terminal
        let emptyCell = Cell(char: " ", style: [])
        buffer = Array(
            repeating: Array(repeating: emptyCell, count: cols),
            count: rows
        )
        // Initialize lastBuffer to match initial empty buffer
        lastBuffer = buffer
    }

    /// Clear the entire cell buffer (fills with spaces and default style).
    public func clearBuffer() {
        let empty = Cell(char: " ", style: [])
        for row in buffer.indices {
            for col in buffer[row].indices {
                buffer[row][col] = empty
            }
        }
    }

    /// Set a single cell at (row, col) in the buffer.
    public func setCell(row: Int, col: Int, char: Character, style: Style = []) {
        guard
            row >= 0, row < buffer.count,
            col >= 0, col < buffer[row].count
        else {
            return
        }
        buffer[row][col] = Cell(char: char, style: style)
    }

    /// Draw a rectangular border around the given region.
    public func drawBorder(
        _ region: Region,
        style borderStyle: BorderStyle = .unicode,
        cellStyle: Style = []
    ) {
        let horizontal, vertical, topLeft, topRight, bottomLeft, bottomRight: Character

        switch borderStyle {
        case .unicode:
            horizontal = "─"
            vertical = "│"
            topLeft = "┌"
            topRight = "┐"
            bottomLeft = "└"
            bottomRight = "┘"
        case .ascii:
            horizontal = "-"
            vertical = "|"
            topLeft = "+"
            topRight = "+"
            bottomLeft = "+"
            bottomRight = "+"
        }

        let top = region.top, left = region.left
        let bottom = top + region.height - 1
        let right = left + region.width - 1

        // Top/bottom edges (only if width >= 2).
        if right > left {
            for columnIndex in (left + 1) ..< right {
                setCell(row: top, col: columnIndex, char: horizontal, style: cellStyle)
                setCell(row: bottom, col: columnIndex, char: horizontal, style: cellStyle)
            }
        }
        // Left/right edges (only if height >= 2).
        if bottom > top {
            for rowIndex in (top + 1) ..< bottom {
                setCell(row: rowIndex, col: left, char: vertical, style: cellStyle)
                setCell(row: rowIndex, col: right, char: vertical, style: cellStyle)
            }
        }
        // Corners (if region is at least 1x1).
        if region.width > 0, region.height > 0 {
            setCell(row: top, col: left, char: topLeft, style: cellStyle)
            if right > left {
                setCell(row: top, col: right, char: topRight, style: cellStyle)
            }
            if bottom > top {
                setCell(row: bottom, col: left, char: bottomLeft, style: cellStyle)
                if right > left {
                    setCell(row: bottom, col: right, char: bottomRight, style: cellStyle)
                }
            }
        }
    }

    /// Flush the buffer to the terminal, respecting per-cell style.
    public func blit() {
        // Only redraw rows that have changed since last blit.
        for (rowIndex, row) in buffer.enumerated() {
            guard rowIndex < lastBuffer.count, row == lastBuffer[rowIndex] else {
                terminal.moveCursor(row: rowIndex + 1, col: 1)
                var skip = 0
                for cell in row {
                    if skip > 0 {
                        skip -= 1
                        continue
                    }
                    terminal.setStyle(cell.style)
                    terminal.output.write(String(cell.char))
                    let width = cell.char.terminalColumnWidth
                    if width > 1 {
                        skip = width - 1
                    }
                }
                terminal.resetStyle()
                continue
            }
        }
        fflush(stdout)
        lastBuffer = buffer
    }

    /// Resize the renderer buffer to the given dimensions, resetting contents.
    public func resize(rows: Int, cols: Int) {
        let empty = Cell(char: " ", style: [])
        buffer = Array(
            repeating: Array(repeating: empty, count: cols),
            count: rows
        )
        lastBuffer = buffer
    }
}

// MARK: - Border and Title Rendering

extension Renderer {
    private struct MaskKey: Hashable {
        let row: Int
        let col: Int
    }

    private struct BorderMask: OptionSet {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
        static let north = BorderMask(rawValue: 1)
        static let south = BorderMask(rawValue: 2)
        static let west  = BorderMask(rawValue: 4)
        static let east  = BorderMask(rawValue: 8)
    }

    public func drawBorders(regions: [Region], widgets: [Widget]) {
        var masks = [MaskKey: BorderMask]()
        var disabledKeys = Set<MaskKey>()
        for (index, region) in regions.enumerated() {
            let disabled = widgets[index].isDisabled
            let hidden = widgets[index].isBorderHidden
            if hidden { continue }
            if region.width == 1, region.height > 1 {
                for row in region.top ..< region.top + region.height {
                    let key = MaskKey(row: row, col: region.left)
                    masks[key, default: []].insert([.north, .south])
                    if disabled { disabledKeys.insert(key) }
                }
            } else if region.width > 1, region.height > 0 {
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
        }
        for (key, mask) in masks {
            let char = boxCharacter(for: mask)
            let style: Style = disabledKeys.contains(key) ? .gray : []
            setCell(row: key.row, col: key.col, char: char, style: style)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func boxCharacter(for mask: BorderMask) -> Character {
        switch mask {
        case [.north, .south, .west, .east]: return "┼"
        case [.south, .west, .east]:         return "┬"
        case [.north, .west, .east]:         return "┴"
        case [.north, .south, .east]:        return "├"
        case [.north, .south, .west]:        return "┤"
        case [.north, .south]:               return "│"
        case [.west, .east]:                 return "─"
        case [.south, .east]:                return "┌"
        case [.south, .west]:                return "┐"
        case [.north, .east]:                return "└"
        case [.north, .west]:                return "┘"
        default:
            return mask.isDisjoint(with: [.north, .south]) ? "─" : "│"
        }
    }

    public func drawTitles(regions: [Region], widgets: [Widget], focusIndex: Int) {
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
                    setCell(row: row, col: startCol + offset, char: char, style: [])
                }
            }
        }
    }
}

// MARK: - EventLoopRenderer conformance

extension Renderer: EventLoopRenderer {}
