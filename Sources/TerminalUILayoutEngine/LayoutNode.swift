import TerminalUICore
import TerminalUIText

/// Retains intrinsic measurements while a rebuilt element tree has the same layout inputs.
/// Custom widgets are measured anew when the tree is rebuilt because their state and theme can affect size.
package final class LayoutNode {
    package private(set) var element: Element
    package private(set) var children: [LayoutNode]
    package weak var textLayout: TextLayoutCache.Entry?
    package var mouse: MouseGeometry?
    package var panelResizeAllocation: StackResizeAllocation?
    package let statistics: RenderingStatistics
    private var measurements: [Int: WidgetSize] = [:]
    private var proposals: [LayoutProposal: WidgetSize] = [:]
    private var widthPreference: LayoutPreference?
    private var heightPreference: LayoutPreference?

    package init(_ element: Element, statistics: RenderingStatistics = RenderingStatistics()) {
        self.element = element
        self.statistics = statistics
        statistics.metrics.reconciliations += 1
        children = element.children.map { LayoutNode($0, statistics: statistics) }
    }

    @discardableResult
    package func update(_ next: Element) -> Bool {
        if case let .boundary(old, _) = element.kind,
           case let .boundary(new, _) = next.kind, old == new { return false }
        statistics.metrics.reconciliations += 1
        mouse = nil
        var changed = !hasSameMeasurement(as: next)
        if changed { textLayout = nil }
        let nextChildren = next.children
        var keyed: [String: LayoutNode] = [:]
        for child in children {
            if case let .boundary(boundary, _) = child.element.kind { keyed[boundary.identity] = child }
        }
        var reconciled: [LayoutNode] = []
        for (index, nextChild) in nextChildren.enumerated() {
            let retained: LayoutNode?
            if case let .boundary(boundary, _) = nextChild.kind {
                retained = keyed[boundary.identity]
            } else if children.indices.contains(index), case .boundary = children[index].element.kind {
                retained = nil
            } else {
                retained = children.indices.contains(index) ? children[index] : nil
            }
            if let retained {
                if retained.update(nextChild) { changed = true }
                reconciled.append(retained)
            } else {
                reconciled.append(LayoutNode(nextChild, statistics: statistics))
                changed = true
            }
        }
        if children.count != reconciled.count || zip(children, reconciled).contains(where: { $0 !== $1 }) { changed = true }
        children = reconciled
        element = next
        if changed {
            measurements.removeAll(keepingCapacity: true)
            proposals.removeAll(keepingCapacity: true)
            widthPreference = nil
            heightPreference = nil
        }
        return changed
    }

    package func measurement(at width: Int) -> WidgetSize? {
        measurements[width]
    }

    package func remember(_ size: WidgetSize, at width: Int) {
        // A node can be proposed several widths by rows, panels and alignment.
        if measurements.count >= 4 { measurements.removeAll(keepingCapacity: true) }
        measurements[width] = size
    }

    package func measurement(for proposal: LayoutProposal) -> WidgetSize? { proposals[proposal] }

    package func preference(vertical: Bool) -> LayoutPreference? { vertical ? heightPreference : widthPreference }

    package func remember(_ preference: LayoutPreference, vertical: Bool) {
        if vertical { heightPreference = preference } else { widthPreference = preference }
    }

    /// Invalidate a stack and the measurements of its enclosing layouts.
    @discardableResult
    package func invalidateLayout(at node: LayoutNode? = nil) -> Bool {
        if let node, self !== node, !children.contains(where: { $0.invalidateLayout(at: node) }) { return false }
        measurements.removeAll(keepingCapacity: true)
        proposals.removeAll(keepingCapacity: true)
        if node == nil { for child in children { child.invalidateLayout() } }
        return true
    }

    package func invalidateMeasurements() {
        measurements.removeAll(keepingCapacity: true)
        proposals.removeAll(keepingCapacity: true)
        widthPreference = nil
        heightPreference = nil
        for child in children { child.invalidateMeasurements() }
    }

    package func remember(_ size: WidgetSize, for proposal: LayoutProposal) {
        if proposals.count >= 8 { proposals.removeAll(keepingCapacity: true) }
        proposals[proposal] = size
    }

    /// Repaint enclosing scroll views and overlays together so clipping and compositing stay intact.
    package func repaintPath(toScroll id: String) -> [LayoutNode]? {
        guard element.isVisible else { return nil }
        switch element.kind {
        case let .scroll(value, _), let .field(value, _, _, _), let .list(value, _, _), let .table(value, _, _, _, _):
            if value == id { return [self] }
        default: break
        }
        for child in children {
            guard let path = child.repaintPath(toScroll: id) else { continue }
            switch element.kind {
            case .scroll, .overlay: return [self]
            default: return [self] + path
            }
        }
        return nil
    }

    private func hasSameMeasurement(as next: Element) -> Bool {
        guard element.isVisible == next.isVisible, element.isEnabled == next.isEnabled,
              element.widthRule == next.widthRule, element.heightRule == next.heightRule,
              element.insets == next.insets,
              element.layoutWidth == next.layoutWidth, element.layoutHeight == next.layoutHeight,
              element.panelResize == next.panelResize,
              element.hasExplicitWidth == next.hasExplicitWidth, element.hasExplicitHeight == next.hasExplicitHeight else { return false }
        switch (element.kind, next.kind) {
        case let (.text(old), .text(new)): return old == new
        case let (.paragraph(old), .paragraph(new)):
            return element.wrapsParagraph == next.wrapsParagraph && old.utf8.elementsEqual(new.utf8)
        case let (.styledParagraph(old), .styledParagraph(new)):
            return element.wrapsParagraph == next.wrapsParagraph
                && old.count == new.count && zip(old, new).allSatisfy { $0.text.utf8.elementsEqual($1.text.utf8) }
        case let (.column(old, _), .column(new, _)), let (.row(old, _), .row(new, _)):
            return old == new
        case let (.button(old, _), .button(new, _)): return old == new
        case let (.field(_, old, oldPlaceholder, oldMultiline), .field(_, new, newPlaceholder, newMultiline)):
            return old == new && oldPlaceholder == newPlaceholder && oldMultiline == newMultiline
        case let (.list(_, old, _), .list(_, new, _)):
            return element.listLineLimit == next.listLineLimit && element.listRowSpacing == next.listRowSpacing
                && old.count == new.count && zip(old, new).allSatisfy { $0.displayTitle == $1.displayTitle }
        case let (.table(_, _, old, _, oldBorder), .table(_, _, new, _, newBorder)):
            return old.count == new.count && oldBorder == newBorder
        case (.boundary, .boundary): return true
        case (.scroll, .scroll), (.panel, .panel), (.dialog, .dialog), (.overlay, .overlay), (.spacer, .spacer), (.divider, .divider):
            return true
        default: return false
        }
    }
}
