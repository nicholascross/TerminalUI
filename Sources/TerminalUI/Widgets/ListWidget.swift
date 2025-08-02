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
    /// Closure invoked when the user confirms or toggles selection.
    /// In single-selection mode, triggered on Enter.
    /// In multiple-selection mode, triggered on Space when toggling items and on Enter.
    /// Parameters are the selected indices and corresponding item strings.
    public var onSelect: (([Int], [String]) -> Void)?

    /// When true, the widget allows selecting multiple items via the space key.
    public var allowsMultipleSelection: Bool = false

    /// Set of indices corresponding to items currently selected when multiple selection is enabled.
    public var selectedItems: Set<Int> = []

    public init(items: [String], title: String? = nil) {
        self.items = items
        self.title = title
    }

    /// Handle navigation keys; returns true if event consumed.
    @discardableResult
    public func handle(event: InputEvent) -> Bool {
        // Ignore input when disabled.
        guard !isDisabled else {
            return false
        }
        // Toggle selection for multiple selection on space.
        if allowsMultipleSelection, case .char(" ") = event {
            if selectedItems.contains(selectedIndex) {
                selectedItems.remove(selectedIndex)
            } else {
                selectedItems.insert(selectedIndex)
            }
            if !items.isEmpty {
                let ids = selectedItems.sorted()
                let sels = ids.map { items[$0] }
                onSelect?(ids, sels)
            }
            return true
        }
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
                if allowsMultipleSelection {
                    let ids = selectedItems.sorted()
                    let sels = ids.map { items[$0] }
                    onSelect?(ids, sels)
                } else {
                    // In single-selection mode, record the selected index
                    selectedItems = [selectedIndex]
                    onSelect?([selectedIndex], [items[selectedIndex]])
                }
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
                let prefixLen = prefix.count
                for (colIndex, character) in text.prefix(region.width).enumerated() {
                    let cellStyle: Style = selectedItems.contains(rowIndex) && colIndex >= prefixLen
                        ? .underline
                        : []
                    renderer.setCell(row: region.top + rowIndex,
                                     col: region.left + colIndex,
                                     char: character,
                                     style: cellStyle)
                }
            }
        case .horizontal:
            var colOffset = 0
            for idx in items.indices {
                let cleaned = items[idx]
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingTabs()
                // Build fixed-width segment so focus brackets don't shift other items
                let segment: String
                if idx == selectedIndex {
                    segment = "[\(cleaned)]"
                } else {
                    segment = " \(cleaned) "
                }
                let text = (idx == 0 ? segment : " " + segment)
                let maxChars = max(region.width - colOffset, 0)
                // Only underline the cleaned text portion for multi-selection
                let cleanedLen = cleaned.count
                // In segment: prefix of 1 (bracket or space), plus an extra space for non-first items
                let baseOffset = (idx == 0 ? 1 : 2)
                for (i, character) in text.prefix(maxChars).enumerated() {
                    let cellStyle: Style = selectedItems.contains(idx)
                        && i >= baseOffset && i < baseOffset + cleanedLen
                        ? .underline
                        : []
                    renderer.setCell(row: region.top,
                                     col: region.left + colOffset + i,
                                     char: character,
                                     style: cellStyle)
                }
                colOffset += text.count
                if colOffset >= region.width { break }
            }
        }
    }
}
