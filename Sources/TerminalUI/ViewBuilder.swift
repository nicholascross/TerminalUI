import TerminalUICore

@MainActor
@resultBuilder
public enum ViewBuilder {
    public static func buildExpression<V: TerminalView>(_ view: V) -> V { view }
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<each V: TerminalView>(_ content: repeat each V) -> TupleView<repeat each V> {
        TupleView(repeat each content)
    }
    public static func buildOptional<V: TerminalView>(_ content: V?) -> OptionalView<V> { OptionalView(content: content) }
    public static func buildEither<A: TerminalView, B: TerminalView>(first: A) -> ConditionalView<A, B> { .first(first) }
    public static func buildEither<A: TerminalView, B: TerminalView>(second: B) -> ConditionalView<A, B> { .second(second) }
    public static func buildArray<V: TerminalView>(_ content: [V]) -> ArrayView<V> { ArrayView(content: content) }
    public static func buildLimitedAvailability<V: TerminalView>(_ content: V) -> AnyTerminalView { AnyTerminalView(content) }
}

public struct EmptyView: PrimitiveView {
    public typealias Body = Never
    public init() {}
    package func lower(path: [CompositionAddress]) -> [Element] { [] }
}

public struct TupleView<each Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let content: (repeat each Content)
    public init(_ content: repeat each Content) { self.content = (repeat each content) }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var output: [Element] = []
        var slot = 0
        for view in repeat each content {
            output += lowerView(view, path: path + [.slot(slot)])
            slot += 1
        }
        return output
    }
}

public struct OptionalView<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let content: Content?
    package func lower(path: [CompositionAddress]) -> [Element] {
        content.map { lowerView($0, path: path + [.branch(1)]) } ?? []
    }
}

public enum ConditionalView<First: TerminalView, Second: TerminalView>: PrimitiveView {
    public typealias Body = Never
    case first(First)
    case second(Second)
    package func lower(path: [CompositionAddress]) -> [Element] {
        switch self {
        case .first(let view): lowerView(view, path: path + [.branch(0)])
        case .second(let view): lowerView(view, path: path + [.branch(1)])
        }
    }
}

/// Ordinary builder loops use positional identity. Use ForEach for stable data identity.
public struct ArrayView<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let content: [Content]
    package func lower(path: [CompositionAddress]) -> [Element] {
        content.enumerated().flatMap { lowerView($0.element, path: path + [.position($0.offset)]) }
    }
}

/// Deliberate erasure for heterogeneous storage and availability boundaries.
public struct AnyTerminalView: PrimitiveView {
    public typealias Body = Never
    private let resolve: ([CompositionAddress]) -> [Element]
    public init<V: TerminalView>(_ view: V) { resolve = { lowerView(view, path: $0) } }
    package func lower(path: [CompositionAddress]) -> [Element] { resolve(path) }
}

public struct ForEach<Items: RandomAccessCollection, ID: Hashable, Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let items: Items
    let id: KeyPath<Items.Element, ID>
    let content: (Items.Element) -> Content
    public init(_ items: Items, id: KeyPath<Items.Element, ID>, @ViewBuilder content: @escaping (Items.Element) -> Content) {
        self.items = items
        self.id = id
        self.content = content
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        var keys: Set<AnyHashable> = []
        return items.map { item in
            let key = AnyHashable(item[keyPath: id])
            precondition(keys.insert(key).inserted, "Duplicate sibling component key '\(key)'")
            var element = Element.component(ViewDescriptor(value: content(item), key: key))
            element.compositionPath = path + [.key(key)]
            return element
        }
    }
}
