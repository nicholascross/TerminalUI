/// A protocol for pluggable layout algorithms.
public protocol LayoutNode {
    /// Update internal state when container size changes (e.g., on resize).
    mutating func update(rows: Int, cols: Int)
    /// Compute regions for rendering the given number of widgets.
    func regions(for widgetCount: Int) -> [Region]
    /// Desired width in cells; nil if flexible (handled by container).
    var desiredWidth: Int? { get }
    /// Desired height in cells; nil if flexible (handled by container).
    var desiredHeight: Int? { get }
    /// Minimum required size (width, height) to display fixed frames in the layout.
    /// Flexible regions contribute zero; fixed frames (.frame) are included.
    func minimalSize(widgetCount: Int) -> (width: Int, height: Int)
}

public extension LayoutNode {
    /// Compute regions for rendering widgets inside an arbitrary container region,
    /// nesting child layouts as needed.
    func regions(for widgetCount: Int, in container: Region) -> [Region] {
        var copy = self
        copy.update(rows: container.height, cols: container.width)
        let regions = copy.regions(for: widgetCount)
        return regions.map { region in
            Region(top: container.top + region.top,
                   left: container.left + region.left,
                   width: region.width,
                   height: region.height)
        }
    }

    /// Default desired width (flexible).
    var desiredWidth: Int? { nil }

    /// Default desired height (flexible).
    var desiredHeight: Int? { nil }

    /// Minimum required size for this layout node (fixed frames only).
    func minimalSize(widgetCount: Int) -> (width: Int, height: Int) {
        return (0, 0)
    }

    /// Constrain this layout leaf to a fixed frame (width/height in cells).
    func frame(width: Int? = nil, height: Int? = nil) -> Sized<Self> {
        Sized(self, width: width, height: height)
    }
}
