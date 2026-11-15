import TerminalUI
import TerminalUICore
import TerminalUIEngine

/// Raw content is available only after explicitly opting into the bridge.
extension Element: TerminalView {
    public typealias Body = Never
}
extension Element: PrimitiveView {
    package func lower(path: [CompositionAddress]) -> [Element] {
        var value = self
        value.compositionPath = path
        return [value]
    }
}

/// Embeds an engine element in typed composition.
public struct EngineContent: TerminalView {
    private let element: Element
    public init(_ element: Element) { self.element = element }
    public var body: Element { return element }
}

/// Hosts a declarative root through the engine presentation-source contract.
@MainActor
public final class ViewPresentation<Root: TerminalView>: TerminalPresentationSource {
    private let adapter: ComponentApplication
    public init(root: Root) { adapter = ComponentApplication(root: root) }
    public var hasPendingUpdates: Bool { adapter.hasPendingUpdates }
    public var revision: UInt64 { adapter.revision }
    public func connect(_ services: PresentationServices) { adapter.connect(services) }
    public func resolve(invalidateRoot: Bool = false) -> Element { adapter.resolve(invalidateRoot: invalidateRoot) }
    public func handle(_ action: UIAction) { adapter.handle(action) }
    public func focusDidChange(_ target: ScopedFocusTarget?) { adapter.focusDidChange(target) }
    public func sizeDidChange(_ size: TerminalSize) { adapter.sizeDidChange(size) }
}

/// Converts typed composition to deferred engine content for explicit mixed applications.
@MainActor
public func engineElement(_ view: some TerminalView) -> Element {
    .component(ViewDescriptor(value: view))
}

extension ElementBuilder {
    @MainActor public static func buildExpression<V: TerminalView>(_ view: V) -> [Element] { lowerView(view) }
}
