import Foundation

/// Wrap a layout leaf with a fixed frame (width and/or height).
public struct Sized<Child: LayoutNode>: LayoutNode {
    /// The child layout node being sized; its update(_:_:) is forwarded to propagate container
    /// size.
    public var wrapped: any LayoutNode
    public let desiredWidth: Int?
    public let desiredHeight: Int?

    public init(_ child: Child, width: Int? = nil, height: Int? = nil) {
        wrapped = child
        desiredWidth = width
        desiredHeight = height
    }

    public mutating func update(rows: Int, cols: Int) {
        // Forward size updates to the wrapped child so it can compute its regions correctly.
        var child = wrapped
        child.update(rows: rows, cols: cols)
        wrapped = child
    }

    public func regions(for widgetCount: Int) -> [Region] {
        wrapped.regions(for: widgetCount)
    }

    /// Minimal size honors fixed width/height or defers to wrapped child.
    public func minimalSize(widgetCount: Int) -> (width: Int, height: Int) {
        let childSize = wrapped.minimalSize(widgetCount: widgetCount)
        let width = desiredWidth ?? childSize.width
        let height = desiredHeight ?? childSize.height
        return (width, height)
    }
}
