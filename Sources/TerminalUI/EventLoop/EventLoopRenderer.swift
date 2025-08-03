import Foundation

/// Protocol defining rendering capabilities for UIEventLoop to manage its virtual screen buffer.
public protocol EventLoopRenderer: AnyObject {
    /// Clear the renderer's internal buffer.
    func clearBuffer()
    /// Set a cell in the buffer at the given row/column with character and style.
    func setCell(row: Int, col: Int, char: Character, style: Style)
    /// Flush the buffer to the terminal or output.
    func blit()
    /// Resize the renderer's buffer to the given dimensions.
    func resize(rows: Int, cols: Int)

    /// Draw borders around widget regions, handling disabled and hidden borders and intersections.
    func drawBorders(regions: [Region], widgets: [Widget])
    /// Draw titles over the top border of each widget region, indicating focus and interactivity.
    func drawTitles(regions: [Region], widgets: [Widget], focusIndex: Int)
}
