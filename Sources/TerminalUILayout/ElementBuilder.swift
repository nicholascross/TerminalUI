import TerminalUICore

/// Collects elements locally. Existing controls and component functions compose without adapters.
@resultBuilder
public enum ElementBuilder {
    public static func buildExpression(_ element: Element) -> [Element] { [element] }
    public static func buildExpression(_ elements: [Element]) -> [Element] { elements }
    public static func buildBlock(_ components: [Element]...) -> [Element] { components.flatMap { $0 } }
    public static func buildOptional(_ component: [Element]?) -> [Element] { component ?? [] }
    public static func buildEither(first component: [Element]) -> [Element] { component }
    public static func buildEither(second component: [Element]) -> [Element] { component }
    public static func buildArray(_ components: [[Element]]) -> [Element] { components.flatMap { $0 } }
    public static func buildLimitedAvailability(_ component: [Element]) -> [Element] { component }
}

public extension Element {
    /// A negotiated column. Flexible descendants make the column flexible on the same axis.
    static func column(spacing: Int = 0, alignment: Alignment = .leading,
                       @ElementBuilder content: () -> [Element]) -> Element {
        .layout(StackLayout(axis: .vertical, spacing: spacing, alignment: alignment), children: content())
    }

    /// A negotiated row. Children are remeasured at their allocated widths before computing height.
    static func row(spacing: Int = 0, alignment: Alignment = .leading,
                    @ElementBuilder content: () -> [Element]) -> Element {
        .layout(StackLayout(axis: .horizontal, spacing: spacing, alignment: alignment), children: content())
    }

    /// Wrappers have one explicit root child; use a row or column to arrange multiple children.
    static func panel(title: String, content: () -> Element) -> Element { .panel(title: title, content: content()) }
    static func scrollView(id: String, followsEnd: Bool = false, content: () -> Element) -> Element {
        .scrollView(id: id, content: content(), followsEnd: followsEnd)
    }
    static func dialog(id: String, title: String, content: () -> Element) -> Element {
        .dialog(id: id, title: title, content: content())
    }
}
