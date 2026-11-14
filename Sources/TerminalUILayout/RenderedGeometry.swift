/// Borrowed geometry for synchronous pointer dispatch. Invalidation also expires captured views.
package final class RenderedGeometry {
    package private(set) var root: LayoutNode?

    package init(root: LayoutNode) {
        self.root = root
    }

    package func invalidate() {
        root = nil
    }
}
