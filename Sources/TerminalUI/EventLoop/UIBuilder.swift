import Foundation

/// Result builder that lets you declare Widgets inline in your layout DSL.
/// Widgets are collected in declaration order, and each is replaced by a WidgetLeaf internally.
@resultBuilder
public enum UIBuilder {
    private static var widgets: [Widget] = []

    /// Reset the collected widget buffer. Called automatically at the start of building.
    static func resetWidgets() {
        widgets = []
    }

    /// The widgets collected during the most recent build.
    public static var collectedWidgets: [Widget] { widgets }

    /// Wrap a raw Widget: record it and emit the corresponding leaf node.
    public static func buildExpression(_ widget: Widget) -> WidgetLeaf {
        let idx = widgets.count
        widgets.append(widget)
        return WidgetLeaf(idx)
    }

    /// Pass through any existing LayoutNode (e.g. Stack, Sized, WidgetLeaf).
    public static func buildExpression(_ node: any LayoutNode) -> any LayoutNode {
        return node
    }

    /// Combine multiple nodes into the root array.
    public static func buildBlock(_ nodes: any LayoutNode...) -> [any LayoutNode] {
        return nodes
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
        columns = cols
    }

    public func regions(for _: Int) -> [Region] {
        return [Region(top: 0, left: 0, width: columns, height: rows)]
    }
}

// Allow calling `.frame(width:height:)` directly on Widgets within the UIBuilder DSL.
public extension Widget {
    /// Record this widget in UIBuilder and wrap it in a fixed-size leaf.
    func frame(width: Int? = nil, height: Int? = nil) -> Sized<WidgetLeaf> {
        let leaf = UIBuilder.buildExpression(self)
        return leaf.frame(width: width, height: height)
    }
}
