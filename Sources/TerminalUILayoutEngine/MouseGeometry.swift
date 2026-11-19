import TerminalUICore

/// Final geometry from a node's most recent paint, in terminal cells.
package struct MouseGeometry {
    package let bounds: MouseRect
    package let clip: MouseRect
    package let enabled: Bool
    package var rows: [(id: String, bounds: MouseRect)] = []
    package var horizontalOffset = 0
    package var verticalOffset = 0
    package var resize: StackResizeGeometry?

    package init(bounds: MouseRect, clip: MouseRect, enabled: Bool) {
        self.bounds = bounds
        self.clip = clip
        self.enabled = enabled
    }
}

package struct StackResizeGeometry {
    package let allocation: StackResizeAllocation
    package let handles: [PanelResizeHandle]

    package init(allocation: StackResizeAllocation, handles: [PanelResizeHandle]) {
        self.allocation = allocation
        self.handles = handles
    }
}

package struct PanelResizeHandle {
    package let index: Int
    package let panel: LayoutNode
    package let bounds: MouseRect

    package init(index: Int, panel: LayoutNode, bounds: MouseRect) {
        self.index = index
        self.panel = panel
        self.bounds = bounds
    }
}
