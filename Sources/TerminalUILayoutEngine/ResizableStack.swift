import TerminalUICore

package struct ResizableStack {
    let layout: StackLayout
    let subviews: [LayoutSubview]
    let panels: [Int: StackPanelResize]
    let previous: StackResizeAllocation?

    package func plan(_ proposal: LayoutProposal) -> (size: WidgetSize, placements: [LayoutPlacement], resize: StackResizeAllocation?) {
        layout.plan(proposal, subviews: subviews, panels: panels, previousResize: previous)
    }
}

package extension LayoutNode {
    /// Component boundaries preserve a panel’s relationship to the containing stack.
    var resizablePanel: LayoutNode? {
        if element.panelResize != nil { return self }
        if case .boundary = element.kind, let child = children.first, child.element.isVisible { return child.resizablePanel }
        return nil
    }

    func resizeDecoration(vertical: Bool) -> Int {
        let insets = element.insets
        let padding = vertical ? insets.top + insets.bottom : insets.leading + insets.trailing
        let inner = if case .boundary = element.kind { children[0].resizeDecoration(vertical: vertical) } else { 2 }
        return min(4096, padding + inner)
    }
}

package extension LayoutMeasurer {
    func resizableStack(of node: LayoutNode, theme: Theme) -> ResizableStack? {
        let layout: StackLayout
        switch node.element.kind {
        case let .layout(strategy, _):
            guard let stack = strategy as? StackLayout else { return nil }
            layout = StackLayout(axis: stack.axis, spacing: stack.spacing, alignment: node.element.alignment ?? stack.alignment)
        case let .row(spacing, _): layout = StackLayout(axis: .horizontal, spacing: spacing, alignment: node.element.alignment ?? .leading)
        case let .column(spacing, _): layout = StackLayout(axis: .vertical, spacing: spacing, alignment: node.element.alignment ?? .leading)
        default: return nil
        }
        let vertical = layout.axis == .vertical
        var panels: [Int: StackPanelResize] = [:]
        for (index, child) in node.children.filter(\.element.isVisible).enumerated() {
            guard let panel = child.resizablePanel?.element.panelResize, panel.edge.vertical == vertical else { continue }
            panels[index] = StackPanelResize(panel: panel, policy: preference(of: child, vertical: vertical, theme: theme),
                                             decoration: child.resizeDecoration(vertical: vertical), preferred: panelSize(panel.stateKey))
        }
        guard !panels.isEmpty else { return nil }
        return ResizableStack(layout: layout, subviews: subviews(of: node, theme: theme), panels: panels, previous: node.panelResizeAllocation)
    }
}
