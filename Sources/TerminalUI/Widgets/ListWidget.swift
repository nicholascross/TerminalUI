import Foundation

/// A simple list widget displaying selectable items, oriented vertically or horizontally.
public class ListWidget: Widget {
    /// Optional title displayed over the top border of the list.
    public var title: String?
    /// This widget handles user input and can be focused.
    public var isUserInteractive: Bool { return true }
    /// When disabled, the widget remains focusable but ignores input events.
    public var isDisabled: Bool = false
    /// When true, the widget's border is hidden (space reserved but not drawn).
    public var isBorderHidden: Bool = false
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
    /// Offset of the first visible item in vertical orientation (for scrolling).
    public var scrollOffset: Int = 0
    /// Horizontal scroll offset (in columns) for horizontal orientation (for scrolling).
    public var horizontalScrollOffset: Int = 0

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
    public func render(into renderer: EventLoopRenderer, region: Region) {
        // Clear entire region to spaces.
        for rowOffset in 0..<region.height {
            for colOffset in 0..<region.width {
                renderer.setCell(row: region.top + rowOffset,
                                 col: region.left + colOffset,
                                 char: " ",
                                 style: [])
            }
        }
        switch orientation {
        case .vertical:
            // Adjust scrollOffset to ensure selected item is visible and within valid range
            let maxOffset = max(0, items.count - region.height)
            if scrollOffset > maxOffset { scrollOffset = maxOffset }
            if selectedIndex < scrollOffset { scrollOffset = selectedIndex }
            if selectedIndex >= scrollOffset + region.height {
                scrollOffset = selectedIndex - region.height + 1
            }
            let start = scrollOffset
            let end = min(items.count, scrollOffset + region.height)
            for (rowOffset, idx) in (start..<end).enumerated() {
                let prefix = (idx == selectedIndex ? "▶ " : "  ")
                let cleaned = items[idx]
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingTabs()
                let text = prefix + cleaned
                let prefixLen = prefix.count
                for (colIndex, character) in text.prefix(region.width).enumerated() {
                    let cellStyle: Style = selectedItems.contains(idx) && colIndex >= prefixLen
                        ? .underline
                        : []
                    renderer.setCell(row: region.top + rowOffset,
                                     col: region.left + colIndex,
                                     char: character,
                                     style: cellStyle)
                }
            }
        case .horizontal:
            // Construct full line segments and style array
            var segments: [String] = []
            var cleanedLens: [Int] = []
            for idx in items.indices {
                let cleaned = items[idx]
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingTabs()
                let segment = (idx == selectedIndex ? "[\(cleaned)]" : " \(cleaned) ")
                let textSegment = (idx == 0 ? segment : " " + segment)
                segments.append(textSegment)
                cleanedLens.append(cleaned.count)
            }
            let fullText = segments.joined()
            let chars = Array(fullText)
            var styleArray = Array<Style>(repeating: [], count: chars.count)
            var pos = 0
            for (idx, segment) in segments.enumerated() {
                let cleanedLen = cleanedLens[idx]
                let baseOffset = (idx == 0 ? 1 : 2)
                if selectedItems.contains(idx) {
                    for i in baseOffset..<baseOffset + cleanedLen where pos + i < styleArray.count {
                        styleArray[pos + i] = .underline
                    }
                }
                pos += segment.count
            }
            // Adjust horizontalScrollOffset to ensure selected segment is visible
            let maxHOffset = max(0, chars.count - region.width)
            if horizontalScrollOffset > maxHOffset { horizontalScrollOffset = maxHOffset }
            let selStart = segments.prefix(selectedIndex).reduce(0) { $0 + $1.count }
            let selEnd = selStart + segments[selectedIndex].count
            if selStart < horizontalScrollOffset {
                horizontalScrollOffset = selStart
            }
            if selEnd > horizontalScrollOffset + region.width {
                horizontalScrollOffset = selEnd - region.width
            }
            // Render visible slice
            let sliceStart = horizontalScrollOffset
            for colIndex in 0..<region.width {
                let textIndex = sliceStart + colIndex
                let (char, cellStyle): (Character, Style) =
                    textIndex < chars.count
                        ? (chars[textIndex], styleArray[textIndex])
                        : (" ", [])
                renderer.setCell(row: region.top,
                                 col: region.left + colIndex,
                                 char: char,
                                 style: cellStyle)
            }
        }
    }
}
