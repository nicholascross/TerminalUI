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

    /// Returns a region inset by a specified number of cells on each side.
    /// The inset reduces width and height by twice the inset, not going below zero.
    func inset(by inset: Int) -> Region {
        Region(top: top + inset,
               left: left + inset,
               width: max(width - 2 * inset, 0),
               height: max(height - 2 * inset, 0))
    }
}
