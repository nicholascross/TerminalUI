import Foundation

/// A rectangular region in the terminal (with zero-based origin).
public struct Region {
    public let top: Int
    public let left: Int
    public let width: Int
    public let height: Int

    public init(top: Int, left: Int, width: Int, height: Int) {
        self.top = top
        self.left = left
        self.width = width
        self.height = height
    }
}

/// Defines screen regions and layout calculations.
public struct Layout {
    public let rows: Int
    public let cols: Int
    /// Height of the input box region, including top and bottom borders and content line.
    public var inputHeight: Int = 3

    public init(rows: Int, cols: Int, inputHeight: Int = 3) {
        self.rows = rows
        self.cols = cols
        self.inputHeight = inputHeight
    }

    /// Height available for main display area.
    public var mainAreaHeight: Int {
        return rows - inputHeight
    }

    /// Offset of the input region from the top.
    public var inputOffset: Int {
        return mainAreaHeight
    }

    /// Region covering the main display area (above the input).
    public var mainRegion: Region {
        Region(top: 0, left: 0, width: cols, height: mainAreaHeight)
    }

    /// Region covering the input area at the bottom.
    public var inputRegion: Region {
        Region(top: inputOffset, left: 0, width: cols, height: inputHeight)
    }

    /// Returns an array of regions for rendering `widgetCount` widgets in order.
    public func regions(for widgetCount: Int) -> [Region] {
        switch widgetCount {
        case 0:
            return []
        case 1:
            // Single widget occupies main region inset by border
            let mb = mainRegion
            return [
                Region(top: mb.top + 1,
                       left: mb.left + 1,
                       width: max(mb.width - 2, 0),
                       height: max(mb.height - 2, 0))
            ]
        case 2:
            // First widget in main region, second in input region
            let mb = mainRegion
            let ib = inputRegion
            let mainInset = Region(top: mb.top + 1,
                                   left: mb.left + 1,
                                   width: max(mb.width - 2, 0),
                                   height: max(mb.height - 2, 0))
            let inputInset = Region(top: ib.top + 1,
                                     left: ib.left + 1,
                                     width: max(ib.width - 2, 0),
                                     height: max(ib.height - 2, 0))
            return [mainInset, inputInset]
        default:
            // Stack widgets vertically, each with a 1-cell border inset
            let heightPer = rows / widgetCount
            return (0..<widgetCount).map { i in
                let top = i * heightPer
                let region = Region(top: top, left: 0, width: cols, height: heightPer)
                return Region(top: region.top + 1,
                              left: region.left + 1,
                              width: max(region.width - 2, 0),
                              height: max(region.height - 2, 0))
            }
        }
    }
}
