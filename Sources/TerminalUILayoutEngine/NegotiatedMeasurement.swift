import TerminalUICore

package extension LayoutMeasurer {
    func subviews(of node: LayoutNode, theme: Theme) -> [LayoutSubview] {
        node.children.filter(\.element.isVisible).map { child in
            LayoutSubview(width: preference(of: child, vertical: false, theme: theme),
                          height: preference(of: child, vertical: true, theme: theme),
                          isSpacer: { if case .spacer = child.element.kind { true } else { false } }()) { proposal in
                measure(child, proposal: proposal, theme: theme)
            }
        }
    }

    func measure(_ node: LayoutNode, proposal: LayoutProposal, theme: Theme) -> WidgetSize {
        if let cached = node.measurement(for: proposal) { return cached }
        node.statistics.metrics.measurements += 1
        let element = node.element
        guard element.isVisible else { return WidgetSize(width: 0, height: 0) }
        let widthPreference = preference(of: node, vertical: false, theme: theme)
        let heightPreference = preference(of: node, vertical: true, theme: theme)
        // A child's own width constraint must affect wrapping before its height is measured.
        let offeredWidth = offered(proposal.width, preference: widthPreference)
        let offeredHeight = offered(proposal.height, preference: heightPreference)
        let horizontal = min(4096, element.insets.leading + element.insets.trailing)
        let vertical = min(4096, element.insets.top + element.insets.bottom)
        let inner = LayoutProposal(width: offeredWidth.map { max(0, $0 - horizontal) },
                                   height: offeredHeight.map { max(0, $0 - vertical) })
        var size: WidgetSize
        switch element.kind {
        case let .layout(strategy, _):
            size = strategy.sizeThatFits(inner, subviews: subviews(of: node, theme: theme))
            size = WidgetSize(width: size.width + horizontal, height: size.height + vertical)
        case .boundary:
            let child = measure(node.children[0], proposal: inner, theme: theme)
            size = WidgetSize(width: child.width + horizontal, height: child.height + vertical)
        case .panel, .dialog:
            let child = measure(node.children[0], proposal: LayoutProposal(
                width: inner.width.map { max(0, $0 - 2) }, height: inner.height.map { max(0, $0 - 2) }), theme: theme)
            size = WidgetSize(width: child.width + horizontal + 2, height: child.height + vertical + 2)
        case .scroll:
            let child = measure(node.children[0], proposal: LayoutProposal(width: inner.width), theme: theme)
            size = WidgetSize(width: inner.width ?? child.width, height: inner.height ?? child.height)
            size = WidgetSize(width: size.width + horizontal, height: size.height + vertical)
        default:
            let measured = measure(node, width: offeredWidth ?? 4096, theme: theme)
            size = WidgetSize(width: measured.0, height: measured.1)
        }
        // Explicit dimensions and caps apply to the complete element, including decoration.
        size.width = constrained(size.width, by: widthPreference)
        size.height = constrained(size.height, by: heightPreference)
        node.remember(size, for: proposal)
        return size
    }

    private func offered(_ available: Int?, preference: LayoutPreference) -> Int? {
        let limit: Int?
        switch preference {
        case let .fixed(value), let .fit(value): limit = max(0, min(4096, value))
        case let .flexible(minimum, maximum, _):
            limit = maximum.map { max(max(0, min(4096, minimum)), max(0, min(4096, $0))) }
        default: limit = nil
        }
        if let limit { return min(available ?? limit, limit) }
        return available
    }

    private func constrained(_ size: Int, by preference: LayoutPreference) -> Int {
        switch preference {
        case let .fixed(value): return max(0, min(4096, value))
        case let .fit(maximum): return min(size, max(0, min(4096, maximum)))
        case let .flexible(minimum, maximum, _):
            let lower = max(0, min(4096, minimum))
            return min(max(size, lower), max(lower, min(4096, maximum ?? 4096)))
        default: return size
        }
    }

    private func preference(of node: LayoutNode, vertical: Bool, theme: Theme) -> LayoutPreference {
        if let cached = node.preference(vertical: vertical) { return cached }
        let result = inferPreference(of: node, vertical: vertical, theme: theme)
        node.remember(result, vertical: vertical)
        return result
    }

    private func inferPreference(of node: LayoutNode, vertical: Bool, theme: Theme) -> LayoutPreference {
        let element = node.element
        let override = vertical ? element.layoutHeight : element.layoutWidth
        if override != .automatic { return override }
        let rule = vertical ? element.heightRule : element.widthRule
        let explicit = vertical ? element.hasExplicitHeight : element.hasExplicitWidth
        if explicit || rule != .content {
            switch rule {
            case .content: return .content
            case let .fixed(value): return .fixed(value)
            case let .fit(maximum): return .fit(maximum: maximum)
            case let .fill(weight): return .flexible(weight: weight)
            }
        }
        switch element.kind {
        case .boundary: return preference(of: node.children[0], vertical: vertical, theme: theme)
        case .scroll, .list, .table, .spacer: return .flexible()
        case .field: return vertical ? .content : .flexible()
        case .panel, .dialog:
            let child = preference(of: node.children[0], vertical: vertical, theme: theme)
            let inset = vertical ? element.insets.top + element.insets.bottom : element.insets.leading + element.insets.trailing
            switch child {
            case let .fixed(value): return .fixed(min(4096, max(0, min(4096, value)) + min(4096, inset) + 2))
            case let .fit(maximum): return .fit(maximum: min(4096, max(0, min(4096, maximum)) + min(4096, inset) + 2))
            case let .flexible(minimum, maximum, weight):
                return .flexible(minimum: min(4096, max(0, min(4096, minimum)) + min(4096, inset) + 2),
                                 maximum: maximum.map { min(4096, max(0, min(4096, $0)) + min(4096, inset) + 2) }, weight: weight)
            default: return .content
            }
        case let .layout(strategy, _):
            let sizing = strategy.sizing(subviews: subviews(of: node, theme: theme))
            let result = vertical ? sizing.height : sizing.width
            return result == .automatic ? .content : result
        default: return .content
        }
    }
}
