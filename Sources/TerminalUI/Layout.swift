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

// MARK: - Region Inset Helper
public extension Region {
    /// Returns a region inset by a specified number of cells on each side.
    /// The inset reduces width and height by twice the inset, not going below zero.
    func inset(by inset: Int = 1) -> Region {
        Region(top: top + inset,
               left: left + inset,
               width: max(width - 2 * inset, 0),
               height: max(height - 2 * inset, 0))
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
            return [mainRegion.inset()]
        case 2:
            // First widget in main region, second in input region
            return [mainRegion.inset(), inputRegion.inset()]
        default:
            // Stack widgets vertically, each with a 1-cell border inset
            let heightPer = rows / widgetCount
            return (0..<widgetCount).map { index in
                let topPosition = index * heightPer
                let region = Region(top: topPosition, left: 0, width: cols, height: heightPer)
                return region.inset()
            }
        }
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
    /// Number of cells to inset for borders around this node.
    var borderInsets: Int { get }
}

extension Layout: LayoutNode {
    public mutating func update(rows: Int, cols: Int) {
        self = Layout(rows: rows, cols: cols, inputHeight: inputHeight)
    }
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
        let regs = copy.regions(for: widgetCount)
        return regs.map { r in
            Region(top: container.top + r.top,
                   left: container.left + r.left,
                   width: r.width,
                   height: r.height)
        }
    }

    /// Default desired width (flexible).
    var desiredWidth: Int? { nil }
    /// Default desired height (flexible).
    var desiredHeight: Int? { nil }
    /// Default insets for borders (none).
    var borderInsets: Int { 0 }
}

/// A horizontal stack layout: lays out its child LayoutNodes side by side.
public struct HStack: LayoutNode {
    public var spacing: Int
    public var children: [LayoutNode]
    private var rows: Int = 0, cols: Int = 0

    public init(spacing: Int = 0, @LayoutBuilder _ build: () -> [LayoutNode]) {
        self.spacing = spacing
        self.children = build()
    }
    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }
    public func regions(for widgetCount: Int) -> [Region] {
        guard !children.isEmpty else { return [] }
        // fixed-size frames and flexible items; share remaining space
        let fixedWidthTotal = children.compactMap { $0.desiredWidth }.reduce(0, +)
        let flexibleCount = children.filter { $0.desiredWidth == nil }.count
        let totalSpacing = spacing * max(0, children.count - 1)
        let availFlexWidth = max(cols - totalSpacing - fixedWidthTotal, 0)
        let flexWidth = flexibleCount > 0 ? availFlexWidth / flexibleCount : 0

        var offsetX = 0
        var out: [Region] = []
        for child in children {
            let childWidth = child.desiredWidth ?? flexWidth
            let outer = Region(top: 0, left: offsetX, width: childWidth, height: rows)
            let inner = child.borderInsets > 0 ? outer.inset(by: child.borderInsets) : outer
            out += child.regions(for: widgetCount, in: inner)
            offsetX += childWidth + spacing
        }
        return out
    }
}

/// A vertical stack layout: lays out its child LayoutNodes top to bottom.
public struct VStack: LayoutNode {
    public var spacing: Int
    public var children: [LayoutNode]
    private var rows: Int = 0, cols: Int = 0

    public init(spacing: Int = 0, @LayoutBuilder _ build: () -> [LayoutNode]) {
        self.spacing = spacing
        self.children = build()
    }
    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }
    public func regions(for widgetCount: Int) -> [Region] {
        guard !children.isEmpty else { return [] }
        // fixed-size frames and flexible items; share remaining space
        let fixedHeightTotal = children.compactMap { $0.desiredHeight }.reduce(0, +)
        let flexibleCount = children.filter { $0.desiredHeight == nil }.count
        let totalSpacing = spacing * max(0, children.count - 1)
        let availFlexHeight = max(rows - totalSpacing - fixedHeightTotal, 0)
        let flexHeight = flexibleCount > 0 ? availFlexHeight / flexibleCount : 0

        var offsetY = 0
        var out: [Region] = []
        for child in children {
            let childHeight = child.desiredHeight ?? flexHeight
            let outer = Region(top: offsetY, left: 0, width: cols, height: childHeight)
            let inner = child.borderInsets > 0 ? outer.inset(by: child.borderInsets) : outer
            out += child.regions(for: widgetCount, in: inner)
            offsetY += childHeight + spacing
        }
        return out
    }
}


/// Wrap a layout leaf with a fixed frame (width and/or height).
public struct Sized<Child: LayoutNode>: LayoutNode {
    public let wrapped: any LayoutNode
    public let desiredWidth: Int?
    public let desiredHeight: Int?
    public init(_ child: Child, width: Int? = nil, height: Int? = nil) {
        self.wrapped = child
        self.desiredWidth = width
        self.desiredHeight = height
    }
    public mutating func update(rows: Int, cols: Int) {
        // no-op; sizing handled by parent stacks/grids
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


/// Wrap a LayoutNode so it draws a 1-cell box around its content.
public struct Bordered<Child: LayoutNode>: LayoutNode {
    public let wrapped: any LayoutNode
    public init(_ child: Child) {
        self.wrapped = child
    }
    public mutating func update(rows: Int, cols: Int) {
        // no-op: content region is already inset by parent stack logic
    }
    // Propagate fixed-size markers through border, adding 1-cell padding on each side
    public var desiredWidth: Int? {
        wrapped.desiredWidth.map { $0 + 2 }
    }
    public var desiredHeight: Int? {
        wrapped.desiredHeight.map { $0 + 2 }
    }
    /// Inset by one cell on each side to leave room for border lines.
    public var borderInsets: Int { 1 }
    public func regions(for widgetCount: Int) -> [Region] {
        wrapped.regions(for: widgetCount)
    }
}

public extension LayoutNode {
    /// Apply a 1-cell border around this layout leaf.
    func bordered() -> Bordered<Self> { Bordered(self) }
}


/// A leaf node that binds one Widget index to the full container region.
public struct WidgetLeaf: LayoutNode {
    public let index: Int
    private var rows: Int = 0, cols: Int = 0

    public init(_ index: Int) {
        self.index = index
    }
    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }
    public func regions(for widgetCount: Int) -> [Region] {
        guard index < widgetCount else { return [] }
        return [Region(top: 0, left: 0, width: cols, height: rows)]
    }
}
