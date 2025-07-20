import Foundation

/// A simple list widget displaying select-able items.
public class ListWidget: Widget {
    /// Optional title displayed over the top border of the list.
    public var title: String?
    /// Items to display in the list.
    public var items: [String]
    /// Currently selected index.
    public var selectedIndex: Int = 0

    public init(items: [String], title: String? = nil) {
        self.items = items
        self.title = title
    }

    /// Handle navigation keys; returns true if event consumed.
    @discardableResult
    public func handle(event: InputEvent) -> Bool {
        switch event {
        case .upArrow:
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case .downArrow:
            selectedIndex = min(items.count - 1, selectedIndex + 1)
            return true
        default:
            return false
        }
    }

    /// Render the list into the given buffer region.
    public func render(into renderer: Renderer, region: Region) {
        let count = min(region.height, items.count)
        // Clear region to spaces.
        for y in 0..<region.height {
            for x in 0..<region.width {
                renderer.setCell(row: region.top + y, col: region.left + x, char: " ")
            }
        }
        // Draw items.
        for i in 0..<count {
            let prefix = (i == selectedIndex ? "▶ " : "  ")
            let text = prefix + items[i]
            for (j, ch) in text.prefix(region.width).enumerated() {
                renderer.setCell(row: region.top + i, col: region.left + j, char: ch)
            }
        }
    }
}
