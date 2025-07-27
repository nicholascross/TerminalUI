import Foundation

public enum Axis {
    case horizontal, vertical
}

public struct Stack: LayoutNode {
    let axis: Axis
    var spacing: Int
    var children: [any LayoutNode]
    private var rows: Int = 0, cols: Int = 0

    public init(axis: Axis, spacing: Int, @UIBuilder _ build: () -> [any LayoutNode]) {
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
        switch axis {
        case .horizontal:
            return computeRegionsHorizontal(widgetCount: widgetCount)
        case .vertical:
            return computeRegionsVertical(widgetCount: widgetCount)
        }
    }

    func computeRegionsHorizontal(widgetCount: Int) -> [Region] {
        let totalSpacing = spacing * max(0, children.count - 1)
        let fixedTotal = children.compactMap { $0.desiredWidth }.reduce(0, +)
        let flexibleCount = children.filter { $0.desiredWidth == nil }.count
        let availFlex = max(cols - totalSpacing - fixedTotal, 0)
        let baseFlex = flexibleCount > 0 ? availFlex / flexibleCount : 0
        let extraFlex = flexibleCount > 0 ? availFlex % flexibleCount : 0
        var remainingFlex = flexibleCount

        var offsetPrimary = 0
        var out: [Region] = []
        for child in children {
            let childSize: Int
            if let width = child.desiredWidth {
                childSize = width
            } else {
                let add = remainingFlex == 1 ? baseFlex + extraFlex : baseFlex
                childSize = add
                remainingFlex -= 1
            }
            let outer = Region(top: 0, left: offsetPrimary, width: childSize, height: rows)
            out += child.regions(for: widgetCount, in: outer)
            offsetPrimary += childSize + spacing
        }
        return out
    }

    func computeRegionsVertical(widgetCount: Int) -> [Region] {
        let totalSpacing = spacing * max(0, children.count - 1)
        let fixedTotal = children.compactMap { $0.desiredHeight }.reduce(0, +)
        let flexibleCount = children.filter { $0.desiredHeight == nil }.count
        let availFlex = max(rows - totalSpacing - fixedTotal, 0)
        let baseFlex = flexibleCount > 0 ? availFlex / flexibleCount : 0
        let extraFlex = flexibleCount > 0 ? availFlex % flexibleCount : 0
        var remainingFlex = flexibleCount

        var offsetPrimary = 0
        var out: [Region] = []
        for child in children {
            let childSize: Int
            if let height = child.desiredHeight {
                childSize = height
            } else {
                let add = remainingFlex == 1 ? baseFlex + extraFlex : baseFlex
                childSize = add
                remainingFlex -= 1
            }
            let outer = Region(top: offsetPrimary, left: 0, width: cols, height: childSize)
            out += child.regions(for: widgetCount, in: outer)
            offsetPrimary += childSize + spacing
        }
        return out
    }

    /// Compute minimal required size to accommodate fixed frames in this stack.
    public func minimalSize(widgetCount: Int) -> (width: Int, height: Int) {
        let childSizes = children.map { $0.minimalSize(widgetCount: widgetCount) }
        let totalSpacing = spacing * max(0, children.count - 1)
        switch axis {
        case .horizontal:
            let width = childSizes.reduce(0) { $0 + $1.width } + totalSpacing
            let height = childSizes.reduce(0) { max($0, $1.height) }
            return (width, height)
        case .vertical:
            let width = childSizes.reduce(0) { max($0, $1.width) }
            let height = childSizes.reduce(0) { $0 + $1.height } + totalSpacing
            return (width, height)
        }
    }
}
