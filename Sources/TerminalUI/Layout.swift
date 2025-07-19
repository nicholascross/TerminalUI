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
}
