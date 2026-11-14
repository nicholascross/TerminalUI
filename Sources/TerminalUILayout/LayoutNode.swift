import TerminalUICore
import TerminalUIText

/// Retains intrinsic measurements while a rebuilt element tree has the same layout inputs.
/// Custom widgets are measured anew when the tree is rebuilt because their state and theme can affect size.
package final class LayoutNode {
    package private(set) var element: Element
    package private(set) var children: [LayoutNode]
    package weak var textLayout: TextLayoutCache.Entry?
    package var mouse: MouseGeometry?
    private var measurements: [Int: WidgetSize] = [:]

    package init(_ element: Element) {
        self.element = element
        children = element.children.map(LayoutNode.init)
    }

    @discardableResult
    package func update(_ next: Element) -> Bool {
        mouse = nil
        var changed = !hasSameMeasurement(as: next)
        if changed { textLayout = nil }
        let nextChildren = next.children
        for (child, nextChild) in zip(children, nextChildren) where child.update(nextChild) {
            changed = true
        }
        if children.count > nextChildren.count {
            children.removeLast(children.count - nextChildren.count)
            changed = true
        } else if children.count < nextChildren.count {
            children.append(contentsOf: nextChildren.dropFirst(children.count).map(LayoutNode.init))
            changed = true
        }
        element = next
        if changed { measurements.removeAll(keepingCapacity: true) }
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
              element.insets == next.insets else { return false }
        switch (element.kind, next.kind) {
        case let (.text(old), .text(new)), let (.paragraph(old), .paragraph(new)):
            return old == new
        case let (.styledParagraph(old), .styledParagraph(new)):
            return old.count == new.count && zip(old, new).allSatisfy { $0.text == $1.text }
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
        case (.scroll, .scroll), (.panel, .panel), (.dialog, .dialog), (.overlay, .overlay), (.spacer, .spacer), (.divider, .divider):
            return true
        default: return false
        }
    }
}
