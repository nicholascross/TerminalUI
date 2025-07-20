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

public enum Axis {
    case horizontal, vertical
}

public struct Stack: LayoutNode {
    let axis: Axis
    var spacing: Int
    var children: [LayoutNode]
    private var rows: Int = 0, cols: Int = 0

    public init(axis: Axis, spacing: Int, @LayoutBuilder _ build: () -> [LayoutNode]) {
        self.axis = axis
        self.spacing = spacing
        self.children = build()
    }

    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public func regions(for widgetCount: Int) -> [Region] {
        guard !children.isEmpty else { return [] }

        let fixedTotal: Int
        let flexibleCount: Int
        let totalSpacing = spacing * max(0, children.count - 1)
        let availFlex: Int
        let flexSize: Int

        switch axis {
        case .horizontal:
            fixedTotal = children.compactMap { $0.desiredWidth }.reduce(0, +)
            flexibleCount = children.filter { $0.desiredWidth == nil }.count
            availFlex = max(cols - totalSpacing - fixedTotal, 0)
            flexSize = flexibleCount > 0 ? availFlex / flexibleCount : 0
        case .vertical:
            fixedTotal = children.compactMap { $0.desiredHeight }.reduce(0, +)
            flexibleCount = children.filter { $0.desiredHeight == nil }.count
            availFlex = max(rows - totalSpacing - fixedTotal, 0)
            flexSize = flexibleCount > 0 ? availFlex / flexibleCount : 0
        }

        var offsetPrimary = 0
        var out: [Region] = []
        for child in children {
            let childSize: Int
            let outer: Region
            switch axis {
            case .horizontal:
                childSize = child.desiredWidth ?? flexSize
                outer = Region(top: 0, left: offsetPrimary, width: childSize, height: rows)
            case .vertical:
                childSize = child.desiredHeight ?? flexSize
                outer = Region(top: offsetPrimary, left: 0, width: cols, height: childSize)
            }
            let inner = outer
            out += child.regions(for: widgetCount, in: inner)
            offsetPrimary += childSize + spacing
        }
        return out
    }
}

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
}

/// A helper to nest multiple LayoutNodes in a SwiftUI-like DSL.
@resultBuilder
public enum LayoutBuilder {
    public static func buildBlock(_ nodes: LayoutNode...) -> [LayoutNode] {
        return nodes
    }
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
}

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
}

public extension LayoutNode {
    /// Constrain this layout leaf to a fixed frame (width/height in cells).
    func frame(width: Int? = nil, height: Int? = nil) -> Sized<Self> {
        Sized(self, width: width, height: height)
    }
}

/// A leaf node that binds one Widget index to the full container region.
public struct WidgetLeaf: LayoutNode {
    public let index: Int
    private var rows: Int = 0
    private var columns: Int = 0

    public init(_ index: Int) {
        self.index = index
    }

    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.columns = cols
    }

    public func regions(for widgetCount: Int) -> [Region] {
        return [Region(top: 0, left: 0, width: columns, height: rows)]
    }
}
