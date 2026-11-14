import TerminalUIComponentRuntime
@_exported import TerminalUILayout

public typealias ComponentMetrics = TerminalUIComponentRuntime.ComponentMetrics
import TerminalUICore

/// A value whose interface is evaluated only after mounting it in a component presentation.
@MainActor
public protocol TerminalView {
    var body: Element { get }
    /// Implementation support for @TerminalComponent. Stateless components use the default.
    mutating func _installState(_ installation: StateInstallation)
}

public extension TerminalView {
    mutating func _installState(_: StateInstallation) {}
}

/// Registers persistent properties, including private state, using stable declaration names.
@attached(member, names: named(_installState))
public macro TerminalComponent() = #externalMacro(module: "TerminalUIComponentMacros", type: "TerminalComponentMacro")

@MainActor
private struct ViewDescriptor<View: TerminalView>: ComponentDescriptor {
    let value: View
    let key: AnyHashable?
    var componentType: ObjectIdentifier {
        ObjectIdentifier(View.self)
    }

    func body(context: AnyObject) -> Element {
        var installed = value
        installed._installState(StateInstallation(context: context as! MountContext))
        return installed.body
    }
}

@MainActor
public func Component(_ view: some TerminalView, key: AnyHashable? = nil) -> Element {
    .component(ViewDescriptor(value: view, key: key))
}

public extension ElementBuilder {
    @MainActor static func buildExpression(_ view: some TerminalView) -> [Element] {
        [Component(view)]
    }
}

/// Repeated components retain their records across insertion and reorder. Keys belong to the owning component.
@MainActor
public func ForEach<Items: RandomAccessCollection>(
    _ items: Items, id: KeyPath<Items.Element, some Hashable>, content: (Items.Element) -> some TerminalView,
) -> [Element] {
    items.map { Component(content($0), key: AnyHashable($0[keyPath: id])) }
}

/// Element-producing repetition inserts a keyed component boundary for each item as well.
@MainActor
public func ForEach<Items: RandomAccessCollection>(
    _ items: Items, id: KeyPath<Items.Element, some Hashable>, content: (Items.Element) -> Element,
) -> [Element] {
    items.map { Component(ElementView(body: content($0)), key: AnyHashable($0[keyPath: id])) }
}

@MainActor
private struct ElementView: TerminalView { let body: Element }
