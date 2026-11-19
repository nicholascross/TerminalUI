import TerminalUICore
import TerminalUIText

package struct LayoutMeasurer {
    let textLayouts: NodeTextLayouts
    let metrics: TextMetrics
    let panelSize: (String) -> Int?

    package init(textLayouts: NodeTextLayouts, metrics: TextMetrics, panelSize: @escaping (String) -> Int? = { _ in nil }) {
        self.textLayouts = textLayouts
        self.metrics = metrics
        self.panelSize = panelSize
    }

    package func measure(_ node: LayoutNode, width: Int, theme: Theme) -> (Int, Int) {
        if let cached = node.measurement(at: width) { return (cached.width, cached.height) }
        node.statistics.metrics.measurements += 1
        let element = node.element
        guard element.isVisible else { return (0, 0) }
        let available = max(1, width - min(width, element.insets.leading + element.insets.trailing))
        let measured: (Int, Int)
        if let stack = resizableStack(of: node, theme: theme) {
            let size = stack.plan(LayoutProposal(width: available)).size
            measured = (size.width, size.height)
        } else {
            measured = intrinsicSize(of: node, width: available, theme: theme)
        }
        var result = (min(4096, measured.0 + min(4096, element.insets.leading + element.insets.trailing)),
                      min(4096, measured.1 + min(4096, element.insets.top + element.insets.bottom)))
        if case let .fixed(width) = element.widthRule { result.0 = min(4096, max(0, width)) }
        if case let .fixed(height) = element.heightRule { result.1 = min(4096, max(0, height)) }
        if case let .fit(maximum) = element.widthRule { result.0 = min(result.0, max(0, maximum)) }
        if case let .fit(maximum) = element.heightRule { result.1 = min(result.1, max(0, maximum)) }
        node.remember(WidgetSize(width: result.0, height: result.1), at: width)
        return result
    }

    private func intrinsicSize(of node: LayoutNode, width available: Int, theme: Theme) -> (Int, Int) {
        let element = node.element
        let measured: (Int, Int)
        switch element.kind {
        case let .text(text):
            measured = (min(available, metrics.cellLength(String(text.prefix(100000).prefix { $0 != "\n" && $0 != "\r" && $0 != "\r\n" }))), 1)
        case let .paragraph(text):
            let layout = textLayouts.layout(text, width: available, retaining: node)
            measured = (min(available, layout.width), layout.lines.count)
        case let .styledParagraph(spans):
            let layout = textLayouts.layout(spans, width: available, retaining: node)
            measured = (layout.width, layout.lines.count)
        case let .button(title, _): measured = (metrics.cellLength(title) + 3 + (element.isEnabled ? 0 : 11), 1)
        case let .field(_, value, placeholder, multiline):
            let text = value.isEmpty ? placeholder : value
            measured = (
                min(available, max(1, metrics.cellLength(text))),
                multiline ? max(1, textLayouts.cache.layout(text, width: available).lines.count) : 1,
            )
        case let .list(_, rows, _):
            let heights = rows.map { min(element.listLineLimit, textLayouts.cache.layout($0.displayTitle, width: max(1, available - 2)).lines.count) }
            measured = (min(available, (rows.map { metrics.cellLength($0.displayTitle) }.max() ?? 0) + 2),
                        max(1, min(4096, heights.reduce(0, +) + max(0, rows.count - 1) * element.listRowSpacing)))
        case let .table(_, _, rows, _, bordered):
            measured = (available, min(4096, rows.count + (bordered ? 4 : 1)))
        case .component: preconditionFailure("Resolve components with ComponentApplication before rendering")
        case .boundary, .scroll: measured = measure(node.children[0], width: available, theme: theme)
        case let .custom(widget):
            let size = UIEvaluationPhase.perform("measurement") { widget.measure(context: WidgetMeasureContext(width: available, theme: theme)) }
            measured = (size.width, size.height)
        case let .layout(strategy, _):
            let size = strategy.sizeThatFits(LayoutProposal(width: available), subviews: subviews(of: node, theme: theme))
            measured = (size.width, size.height)
        case .spacer: measured = (0, 0)
        case .divider: measured = (1, 1)
        case .panel, .dialog:
            let size = measure(node.children[0], width: max(1, available - 2), theme: theme)
            measured = (min(4096, size.0 + 2), min(4096, size.1 + 2))
        case .overlay: measured = measure(node.children[0], width: available, theme: theme)
        case let .column(spacing, _):
            let sizes = node.children.filter(\.element.isVisible).map { measure($0, width: available, theme: theme) }
            measured = (
                sizes.map(\.0).max() ?? 0,
                min(4096, sizes.reduce(0) { min(4096, $0 + $1.1) } + min(4096, max(0, sizes.count - 1) * min(4096, spacing))),
            )
        case let .row(spacing, _):
            let sizes = node.children.filter(\.element.isVisible).map { measure($0, width: available, theme: theme) }
            measured = (
                min(4096, sizes.reduce(0) { min(4096, $0 + $1.0) } + min(4096, max(0, sizes.count - 1) * min(4096, spacing))),
                sizes.map(\.1).max() ?? 0,
            )
        }
        return measured
    }
}
