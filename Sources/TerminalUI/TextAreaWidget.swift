import Foundation

/// A text area widget for displaying multiple lines of text.
public class TextAreaWidget: Widget {
    /// Optional title displayed over the top border of the text area.
    public var title: String?
    /// Determines whether the text area accepts scroll input and can receive focus.
    public let isUserInteractive: Bool
    /// Lines of text to display in the area.
    public var lines: [String]
    /// Current scroll offset (index of the topmost displayed line).
    public var scrollOffset: Int = 0

    public init(
        lines: [String],
        title: String? = nil,
        isUserInteractive: Bool = true
    ) {
        self.lines = lines
        self.title = title
        self.isUserInteractive = isUserInteractive
    }

    /// Full text content: joined lines separated by newlines.
    public var text: String {
        get { lines.joined(separator: "\n") }
        set { lines = newValue.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) }
    }

    /// Convenience initializer accepting a single string; splits on newlines for display.
    public convenience init(
        text: String,
        title: String? = nil,
        isUserInteractive: Bool = true
    ) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        self.init(lines: lines, title: title, isUserInteractive: isUserInteractive)
    }

    /// Handle scrolling events (up/down arrows). Returns true if event consumed.
    @discardableResult
    public func handle(event: InputEvent) -> Bool {
        switch event {
        case .upArrow:
            scrollOffset = max(0, scrollOffset - 1)
            return true
        case .downArrow:
            scrollOffset += 1
            return true
        default:
            return false
        }
    }

    /// Render the text area into the given region, showing visible lines.
    public func render(into renderer: Renderer, region: Region) {
        // Clamp scroll offset to valid range
        let maxOffset = max(0, lines.count - region.height)
        scrollOffset = min(scrollOffset, maxOffset)
        // Clear region to spaces
        for y in 0..<region.height {
            for x in 0..<region.width {
                renderer.setCell(row: region.top + y, col: region.left + x, char: " ")
            }
        }
        // Draw visible lines
        let endLine = min(scrollOffset + region.height, lines.count)
        for (i, line) in lines[scrollOffset..<endLine].enumerated() {
            for (j, ch) in line.prefix(region.width).enumerated() {
                renderer.setCell(row: region.top + i, col: region.left + j, char: ch)
            }
        }
    }
}
