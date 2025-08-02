import Foundation

/// A simple list widget displaying selectable items, oriented vertically or horizontally.
public class ListWidget: Widget {
    /// Optional title displayed over the top border of the list.
    public var title: String?
    /// This widget handles user input and can be focused.
    public var isUserInteractive: Bool { return true }
    /// When disabled, the widget remains focusable but ignores input events.
    public var isDisabled: Bool = false
    /// Items to display in the list.
    /// Orientation of the list: vertical (default) or horizontal.
    public var orientation: Axis = .vertical
    public var items: [String]
    /// Currently selected index.
    public var selectedIndex: Int = 0
    /// Closure invoked when the user presses Enter on the current selection.
    /// Parameters are the selected index and corresponding item string.
    public var onSelect: ((Int, String) -> Void)?

    public init(items: [String], title: String? = nil) {
        self.items = items
        self.title = title
    }

    /// Handle navigation keys; returns true if event consumed.
    @discardableResult
    public func handle(event: InputEvent) -> Bool {
        switch (orientation, event) {
        case (.vertical, .upArrow):
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case (.vertical, .downArrow):
            selectedIndex = min(items.count - 1, selectedIndex + 1)
            return true
        case (.horizontal, .leftArrow):
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case (.horizontal, .rightArrow):
            selectedIndex = min(items.count - 1, selectedIndex + 1)
            return true
        case (_, .enter):
            if !items.isEmpty {
                onSelect?(selectedIndex, items[selectedIndex])
            }
            return true
        default:
            return false
        }
    }

    /// Render the list into the given buffer region.
    public func render(into renderer: Renderer, region: Region) {
        // Clear entire region to spaces.
        for rowOffset in 0..<region.height {
            for colOffset in 0..<region.width {
                renderer.setCell(row: region.top + rowOffset,
                                 col: region.left + colOffset,
                                 char: " ")
            }
        }
        switch orientation {
        case .vertical:
            let count = min(region.height, items.count)
            for rowIndex in 0..<count {
                let prefix = (rowIndex == selectedIndex ? "▶ " : "  ")
                let cleaned = items[rowIndex]
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingTabs()
                let text = prefix + cleaned
                for (colIndex, character) in text.prefix(region.width).enumerated() {
                    renderer.setCell(row: region.top + rowIndex,
                                     col: region.left + colIndex,
                                     char: character)
                }
            }
        case .horizontal:
            var colOffset = 0
            for idx in items.indices {
                let prefix = (idx == selectedIndex ? "▶ " : "  ")
                let cleaned = items[idx]
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingTabs()
                let text = prefix + cleaned
                let maxChars = max(region.width - colOffset, 0)
                for (i, character) in text.prefix(maxChars).enumerated() {
                    renderer.setCell(row: region.top,
                                     col: region.left + colOffset + i,
                                     char: character)
                }
                colOffset += text.count
                if colOffset >= region.width { break }
            }
        }
    }
}
