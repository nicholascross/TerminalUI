import TerminalUICore

public struct Column<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let spacing: Int
    let alignment: Alignment
    let content: Content
    public init(spacing: Int = 0, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content()
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.layout(StackLayout(axis: .vertical, spacing: spacing, alignment: alignment), children: lowerView(content, path: path))
        element.compositionPath = path
        return [element]
    }
}

public struct Row<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let spacing: Int
    let alignment: Alignment
    let content: Content
    public init(spacing: Int = 0, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.alignment = alignment
        self.content = content()
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.layout(StackLayout(axis: .horizontal, spacing: spacing, alignment: alignment), children: lowerView(content, path: path))
        element.compositionPath = path
        return [element]
    }
}

public struct Panel<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let title: String
    let content: Content
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.panel(title: title, content: rootElement(lowerView(content, path: path)))
        element.compositionPath = path
        return [element]
    }
}

public struct ScrollView<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let id: String
    let followsEnd: Bool
    let content: Content
    public init(id: String, followsEnd: Bool = false, @ViewBuilder content: () -> Content) {
        self.id = id
        self.followsEnd = followsEnd
        self.content = content()
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.scrollView(id: id, content: rootElement(lowerView(content, path: path)), followsEnd: followsEnd)
        element.compositionPath = path
        return [element]
    }
}

public struct Dialog<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let id: String
    let title: String
    let content: Content
    public init(id: String, title: String, @ViewBuilder content: () -> Content) {
        self.id = id
        self.title = title
        self.content = content()
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.dialog(id: id, title: title, content: rootElement(lowerView(content, path: path)))
        element.compositionPath = path
        return [element]
    }
}
