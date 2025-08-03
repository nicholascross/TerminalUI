import Foundation

/// A text input widget capturing line input.
public class TextInputWidget: Widget {
    /// Optional title displayed over the top border of the input.
    public var title: String?
    /// This widget handles user input and can be focused.
    public var isUserInteractive: Bool { true }
    /// When disabled, the widget remains focusable but ignores input events.
    public var isDisabled: Bool = false
    /// When true, the widget's border is hidden (space reserved but not drawn).
    public var isBorderHidden: Bool
    /// Prompt shown before input.
    public let prompt: String
    /// Called when this widget submits text (e.g. Ctrl-D).
    public var onSubmit: ((String) -> Void)?

    /// Current input as a multi-line buffer.
    private var lines: [String] = [""]
    /// Cursor position within the buffer.
    var cursorRow: Int = 0
    var cursorCol: Int = 0
    /// Vertical scroll offset for multi-line display.
    var scrollOffset: Int = 0

    /// Combined buffer as a single string with newlines.
    public var buffer: String { lines.joined(separator: "\n") }

    public init(prompt: String = "> ", title: String? = nil, isBorderHidden: Bool = false) {
        self.prompt = prompt
        self.title = title
        self.isBorderHidden = isBorderHidden
    }

    /// Handle character and control events; returns full buffer on submit (Ctrl-D).
    @discardableResult
    public func handle(event: InputEvent) -> String? {
        switch event {
        case .char(let character):
            // Treat newline characters as enter events to split lines
            if character.isNewline {
                let line = lines[cursorRow]
                let prefix = String(line.prefix(cursorCol))
                let suffix = String(line.dropFirst(cursorCol))
                lines[cursorRow] = prefix
                lines.insert(suffix, at: cursorRow + 1)
                cursorRow += 1
                cursorCol = 0
                return nil
            }
            // Insert character at cursor
            let line = lines[cursorRow]
            let prefix = String(line.prefix(cursorCol))
            let suffix = String(line.dropFirst(cursorCol))
            lines[cursorRow] = prefix + String(character) + suffix
            cursorCol += 1
            return nil

        case .enter:
            // Insert newline at cursor
            let line = lines[cursorRow]
            let prefix = String(line.prefix(cursorCol))
            let suffix = String(line.dropFirst(cursorCol))
            lines[cursorRow] = prefix
            lines.insert(suffix, at: cursorRow + 1)
            cursorRow += 1
            cursorCol = 0
            return nil

        case .backspace:
            if cursorCol > 0 {
                let line = lines[cursorRow]
                let idx = line.index(line.startIndex, offsetBy: cursorCol - 1)
                let prefix = String(line[..<idx])
                let suffix = String(line[line.index(after: idx)...])
                lines[cursorRow] = prefix + suffix
                cursorCol -= 1
            } else if cursorRow > 0 {
                // Join with previous line
                let prevLen = lines[cursorRow - 1].count
                lines[cursorRow - 1] += lines[cursorRow]
                lines.remove(at: cursorRow)
                cursorRow -= 1
                cursorCol = prevLen
            }
            return nil

        case .leftArrow:
            if cursorCol > 0 {
                cursorCol -= 1
            } else if cursorRow > 0 {
                cursorRow -= 1
                cursorCol = lines[cursorRow].count
            }
            return nil

        case .rightArrow:
            if cursorCol < lines[cursorRow].count {
                cursorCol += 1
            } else if cursorRow < lines.count - 1 {
                cursorRow += 1
                cursorCol = 0
            }
            return nil

        case .upArrow:
            if cursorRow > 0 {
                cursorRow -= 1
                cursorCol = min(cursorCol, lines[cursorRow].count)
            }
            return nil

        case .downArrow:
            if cursorRow < lines.count - 1 {
                cursorRow += 1
                cursorCol = min(cursorCol, lines[cursorRow].count)
            }
            return nil

        case .submit:
            // Submit the entire buffer (e.g. on Ctrl-D)
            let text = buffer
            lines = [""]
            cursorRow = 0
            cursorCol = 0
            scrollOffset = 0
            onSubmit?(text)
            return text

        default:
            return nil
        }
    }

    /// Render the input prompt and buffer into the given region, scrolling to cursor.
    public func render(into renderer: EventLoopRenderer, region: Region) {
        // Adjust vertical scroll to ensure cursor is visible
        if cursorRow < scrollOffset {
            scrollOffset = cursorRow
        }
        if cursorRow >= scrollOffset + region.height {
            scrollOffset = cursorRow - region.height + 1
        }
        // Clear full region
        for rowOffset in 0..<region.height {
            for colOffset in 0..<region.width {
                renderer.setCell(row: region.top + rowOffset,
                                 col: region.left + colOffset,
                                 char: " ",
                                 style: [])
            }
        }
        // Draw visible lines (prefix prompt on first buffer line)
        let end = min(lines.count, scrollOffset + region.height)
        for (visIndex, globalIndex) in (scrollOffset..<end).enumerated() {
            let line = lines[globalIndex]
            let cleaned = line.replacingTabs()
            let text = (globalIndex == 0 ? prompt + cleaned : cleaned)
            for (charIndex, char) in text.prefix(region.width).enumerated() {
                renderer.setCell(row: region.top + visIndex,
                                 col: region.left + charIndex,
                                 char: char,
                                 style: [])
            }
        }
    }
}

// MARK: - Widget conformance
// MARK: - Widget conformance
extension TextInputWidget {
    /// Consume input events relevant to text editing.
    public func handle(event: InputEvent) -> Bool {
        switch event {
        case .char, .enter, .backspace,
             .leftArrow, .rightArrow, .upArrow, .downArrow,
             .submit:
            // Invoke the String-returning handler to update buffer/cursor
            _ = (self.handle as (InputEvent) -> String?)(event)
            return true
        default:
            return false
        }
    }
}
