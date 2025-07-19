import Foundation

/// Defines screen regions and layout calculations.
public struct Layout {
    public let rows: Int
    public let cols: Int
    public var inputHeight: Int = 1

    public init(rows: Int, cols: Int, inputHeight: Int = 1) {
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
}
