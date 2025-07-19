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

/// A protocol for pluggable layout algorithms.
public protocol LayoutNode {
    /// Update internal state when container size changes (e.g., on resize).
    mutating func update(rows: Int, cols: Int)
    /// Compute regions for rendering the given number of widgets.
    func regions(for widgetCount: Int) -> [Region]
}

extension Layout: LayoutNode {
    public mutating func update(rows: Int, cols: Int) {
        self = Layout(rows: rows, cols: cols, inputHeight: inputHeight)
    }
}

/// A simple flow layout (horizontal or vertical) that arranges widgets in sequence with optional wrapping.
public struct FlowLayout: LayoutNode {
    public enum Direction { case horizontal, vertical }
    public var direction: Direction
    public var spacing: Int
    private var rows: Int
    private var cols: Int

    public init(rows: Int, cols: Int, direction: Direction = .horizontal, spacing: Int = 0) {
        self.rows = rows
        self.cols = cols
        self.direction = direction
        self.spacing = spacing
    }

    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public func regions(for widgetCount: Int) -> [Region] {
        guard widgetCount > 0 else { return [] }
        switch direction {
        case .horizontal:
            let totalSpacing = spacing * (widgetCount - 1)
            let widthPer = (cols - totalSpacing) / widgetCount
            return (0..<widgetCount).map { i in
                let left = i * (widthPer + spacing)
                let region = Region(top: 0, left: left, width: widthPer, height: rows)
                return Region(top: region.top + 1,
                              left: region.left + 1,
                              width: max(region.width - 2, 0),
                              height: max(region.height - 2, 0))
            }
        case .vertical:
            let totalSpacing = spacing * (widgetCount - 1)
            let heightPer = (rows - totalSpacing) / widgetCount
            return (0..<widgetCount).map { i in
                let top = i * (heightPer + spacing)
                let region = Region(top: top, left: 0, width: cols, height: heightPer)
                return Region(top: region.top + 1,
                              left: region.left + 1,
                              width: max(region.width - 2, 0),
                              height: max(region.height - 2, 0))
            }
        }
    }
}

/// A grid layout dividing the container into a fixed number of columns (and computed rows).
public struct GridLayout: LayoutNode {
    public var columns: Int
    public var spacing: Int
    private var rows: Int
    private var cols: Int

    public init(rows: Int, cols: Int, columns: Int, spacing: Int = 0) {
        self.rows = rows
        self.cols = cols
        self.columns = max(1, columns)
        self.spacing = spacing
    }

    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public func regions(for widgetCount: Int) -> [Region] {
        guard widgetCount > 0 else { return [] }
        let colsCount = columns
        let rowsCount = Int(ceil(Double(widgetCount) / Double(colsCount)))
        let totalHSpacing = spacing * max(0, colsCount - 1)
        let totalVSpacing = spacing * max(0, rowsCount - 1)
        let cellWidth = (cols - totalHSpacing) / colsCount
        let cellHeight = (rows - totalVSpacing) / rowsCount
        return (0..<widgetCount).map { i in
            let r = i / colsCount
            let c = i % colsCount
            let left = c * (cellWidth + spacing)
            let top = r * (cellHeight + spacing)
            let region = Region(top: top, left: left, width: cellWidth, height: cellHeight)
            return Region(top: region.top + 1,
                          left: region.left + 1,
                          width: max(region.width - 2, 0),
                          height: max(region.height - 2, 0))
        }
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
        // count dividers and fixed-size frames, then divide remaining space among flex items
        let dividerCount = children.filter { $0 is Divider }.count
        let sizeMarkers = children.compactMap { $0 as? SizedMarker }.filter { $0.desiredWidth != nil }
        let fixedWidthTotal = sizeMarkers.compactMap { $0.desiredWidth }.reduce(0, +)
        let flexibleCount = children.count - dividerCount - sizeMarkers.count
        let totalSpacing = spacing * max(0, children.count - 1)
        let totalDividerWidth = dividerCount
        let availFlexWidth = max(cols - totalSpacing - totalDividerWidth - fixedWidthTotal, 0)
        let flexWidth = flexibleCount > 0 ? availFlexWidth / flexibleCount : 0
        var x = 0
        var out: [Region] = []
        for child in children {
            // determine width: divider=1, fixed if Sized.frame(width:), else flexible
            let w: Int = {
                switch child {
                case is Divider: return 1
                case let s as SizedMarker where s.desiredWidth != nil: return s.desiredWidth!
                default: return flexWidth
                }
            }()
            let outer = Region(top: 0, left: x, width: w, height: rows)
            if child is Divider {
                out += child.regions(for: widgetCount, in: outer)
            } else if let b = child as? BorderedMarker {
                // inset content to leave room for its border
                let sub = Region(top: outer.top + 1,
                                 left: outer.left + 1,
                                 width: max(outer.width - 2, 0),
                                 height: max(outer.height - 2, 0))
                out += b.wrapped.regions(for: widgetCount, in: sub)
            } else {
                out += child.regions(for: widgetCount, in: outer)
            }
            x += w + spacing
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
        // count dividers and fixed-height frames, then share remaining space
        let dividerCount = children.filter { $0 is Divider }.count
        let sizeMarkers = children.compactMap { $0 as? SizedMarker }.filter { $0.desiredHeight != nil }
        let fixedHeightTotal = sizeMarkers.compactMap { $0.desiredHeight }.reduce(0, +)
        let flexibleCount = children.count - dividerCount - sizeMarkers.count
        let totalSpacing = spacing * max(0, children.count - 1)
        let totalDividerHeight = dividerCount
        let availFlexHeight = max(rows - totalSpacing - totalDividerHeight - fixedHeightTotal, 0)
        let flexHeight = flexibleCount > 0 ? availFlexHeight / flexibleCount : 0
        var y = 0
        var out: [Region] = []
        for child in children {
            let h: Int = {
                switch child {
                case is Divider: return 1
                case let s as SizedMarker where s.desiredHeight != nil: return s.desiredHeight!
                default: return flexHeight
                }
            }()
            let outer = Region(top: y, left: 0, width: cols, height: h)
            if let _ = child as? Divider {
                out += child.regions(for: widgetCount, in: outer)
            } else if let b = child as? BorderedMarker {
                // inset content to leave room for its border
                let sub = Region(top: outer.top + 1,
                                 left: outer.left + 1,
                                 width: max(outer.width - 2, 0),
                                 height: max(outer.height - 2, 0))
                out += b.wrapped.regions(for: widgetCount, in: sub)
            } else {
                out += child.regions(for: widgetCount, in: outer)
            }
            y += h + spacing
        }
        return out
    }
}

/// A grid layout dividing the container into a fixed number of columns.
public struct Grid: LayoutNode {
    public var columns: Int
    public var spacing: Int
    private var rows: Int = 0, cols: Int = 0
    public var children: [LayoutNode]

    public init(columns: Int, spacing: Int = 0, @LayoutBuilder _ build: () -> [LayoutNode]) {
        self.columns = max(1, columns)
        self.spacing = spacing
        self.children = build()
    }
    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }
    public func regions(for widgetCount: Int) -> [Region] {
        guard !children.isEmpty else { return [] }
        let cCount = columns
        let rCount = Int(ceil(Double(children.count) / Double(cCount)))
        let totalH = spacing * max(0, cCount - 1)
        let totalV = spacing * max(0, rCount - 1)
        let w = (cols - totalH) / cCount
        let h = (rows - totalV) / rCount
        var out: [Region] = []
        for (i, child) in children.enumerated() {
            let r = i / cCount, c = i % cCount
            let outer = Region(top: r * (h + spacing),
                               left: c * (w + spacing),
                               width: w, height: h)
            if let _ = child as? Divider {
                out += child.regions(for: widgetCount, in: outer)
            } else if let b = child as? BorderedMarker {
                // inset content to leave room for its border
                let sub = Region(top: outer.top + 1,
                                 left: outer.left + 1,
                                 width: max(outer.width - 2, 0),
                                 height: max(outer.height - 2, 0))
                out += b.wrapped.regions(for: widgetCount, in: sub)
            } else {
                out += child.regions(for: widgetCount, in: outer)
            }
        }
        return out
    }
}
/// A marker protocol for layout leaves that request fixed width and/or height.
public protocol SizedMarker {
    /// The wrapped child layout to size.
    var wrapped: any LayoutNode { get }
    /// Desired width in cells; nil if flexible.
    var desiredWidth: Int? { get }
    /// Desired height in cells; nil if flexible.
    var desiredHeight: Int? { get }
}

/// Wrap a layout leaf with a fixed frame (width and/or height).
public struct Sized<Child: LayoutNode>: LayoutNode, SizedMarker {
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

/// A marker protocol for layout leaves that request a surrounding 1-cell border.
public protocol BorderedMarker {
    /// The wrapped child layout to which the 1-cell border will be applied.
    var wrapped: any LayoutNode { get }
}

/// Wrap a LayoutNode so it draws a 1-cell box around its content.
public struct Bordered<Child: LayoutNode>: LayoutNode, BorderedMarker, SizedMarker {
    public let wrapped: any LayoutNode
    public init(_ child: Child) {
        self.wrapped = child
    }
    public mutating func update(rows: Int, cols: Int) {
        // no-op: content region is already inset by parent stack logic
    }
    // Propagate fixed-size markers through border, adding 1-cell padding on each side
    public var desiredWidth: Int? {
        (wrapped as? any SizedMarker)?.desiredWidth.map { $0 + 2 }
    }
    public var desiredHeight: Int? {
        (wrapped as? any SizedMarker)?.desiredHeight.map { $0 + 2 }
    }
    public func regions(for widgetCount: Int) -> [Region] {
        wrapped.regions(for: widgetCount)
    }
}

public extension LayoutNode {
    /// Apply a 1-cell border around this layout leaf.
    func bordered() -> Bordered<Self> { Bordered(self) }
}

/// A divider line that, in an HStack, is drawn vertically (1-column thick),
/// or in a VStack is drawn horizontally (1-row thick).
public struct Divider: LayoutNode {
    private var rows: Int = 0, cols: Int = 0
    public init() {}
    public mutating func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }
    public func regions(for widgetCount: Int) -> [Region] {
        [Region(top: 0, left: 0, width: cols, height: rows)]
    }
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
/// A lightweight constraint-based layout using simple anchor relations between widgets.
public class ConstraintLayout: LayoutNode {
    /// Constrainable widget attributes.
    public enum Attribute {
        case left, right, top, bottom, width, height
    }

    /// An anchor on a widget's attribute.
    public struct Anchor {
        public let widgetIndex: Int
        public let attribute: Attribute
        public init(_ widgetIndex: Int, _ attribute: Attribute) {
            self.widgetIndex = widgetIndex
            self.attribute = attribute
        }
    }

    /// A linear constraint between two anchors or an anchor and a constant.
    public struct Constraint {
        public enum Relation { case equal, lessThanOrEqual, greaterThanOrEqual }
        public let first: Anchor
        public let relation: Relation
        public let second: Anchor?
        public let constant: Int

        public init(
            _ first: Anchor,
            _ relation: Relation,
            _ second: Anchor? = nil,
            constant: Int = 0
        ) {
            self.first = first
            self.relation = relation
            self.second = second
            self.constant = constant
        }
    }

    private var rows: Int
    private var cols: Int
    private var constraints: [Constraint] = []

    /// Create a constraint layout for the given container size.
    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    /// Add a layout constraint.
    public func addConstraint(_ constraint: Constraint) {
        constraints.append(constraint)
    }

    /// Remove all constraints.
    public func clearConstraints() {
        constraints.removeAll()
    }

    public func update(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public func regions(for widgetCount: Int) -> [Region] {
        // Fall back to absolute layout if no constraints.
        guard !constraints.isEmpty else {
            return Layout(rows: rows, cols: cols).regions(for: widgetCount)
        }
        // Build variables: [left, top, width, height] per widget
        let varsPer = 4
        let varCount = widgetCount * varsPer
        // Build equations: var[first] - var[second] == constant  (or var[first] == constant)
        var mat: [[Double]] = []
        func idx(_ anchor: Anchor) -> Int {
            guard anchor.widgetIndex >= 0 && anchor.widgetIndex < widgetCount else { return -1 }
            let base = anchor.widgetIndex * varsPer
            switch anchor.attribute {
            case .left:   return base + 0
            case .top:    return base + 1
            case .width:  return base + 2
            case .height: return base + 3
            case .right, .bottom:
                // unsupported compound attribute
                return -1
            }
        }
        for c in constraints {
            // only equal relation supported
            guard c.relation == .equal else { continue }
            var row = [Double](repeating: 0.0, count: varCount + 1)
            let i1 = idx(c.first)
            guard i1 >= 0 else { continue }
            row[i1] = 1.0
            if let sec = c.second {
                let i2 = idx(sec)
                if i2 >= 0 {
                    row[i2] = -1.0
                }
            }
            row[varCount] = Double(c.constant)
            mat.append(row)
        }
        // Solve linear system mat * x = b via Gauss-Jordan
        let eqs = mat.count
        var m = mat
        var r = 0
        for col in 0..<varCount where r < eqs {
            // pivot search
            var pivot = r
            while pivot < eqs && abs(m[pivot][col]) < 1e-6 { pivot += 1 }
            guard pivot < eqs else { continue }
            m.swapAt(r, pivot)
            let div = m[r][col]
            for j in col..<varCount+1 { m[r][j] /= div }
            for i in 0..<eqs where i != r {
                let mult = m[i][col]
                for j in col..<varCount+1 {
                    m[i][j] -= mult * m[r][j]
                }
            }
            r += 1
        }
        var sol = [Double](repeating: 0.0, count: varCount)
        for i in 0..<r {
            if let lead = m[i].prefix(varCount).firstIndex(where: { abs($0) > 1e-6 }) {
                sol[lead] = m[i][varCount]
            }
        }
        // Build regions from solution, defaulting missing dims to full span
        return (0..<widgetCount).map { i in
            let base = i * varsPer
            let x = Int(sol[base + 0])
            let y = Int(sol[base + 1])
            let w = Int(sol[base + 2] > 0 ? sol[base + 2] : Double(cols))
            let h = Int(sol[base + 3] > 0 ? sol[base + 3] : Double(rows))
            return Region(top: y, left: x, width: w, height: h)
        }
    }
}
