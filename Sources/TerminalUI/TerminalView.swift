import TerminalUIComponentRuntime
import TerminalUICore

/// A declarative value evaluated after its persistent properties have been installed.
@MainActor
public protocol TerminalView {
    associatedtype Body: TerminalView
    @ViewBuilder var body: Body { get }
    /// Compiler support for @TerminalComponent; applications should not call this directly.
    mutating func _installState(_ installation: StateInstallation)
}

extension TerminalView {
    public mutating func _installState(_: StateInstallation) {}
}

extension TerminalView where Body == Never {
    public var body: Never { fatalError("Primitive views have no body") }
}

extension Never: TerminalView {
    public typealias Body = Never
}

/// Registers private persistent properties by stable declaration names.
@attached(member, names: named(_installState))
public macro TerminalComponent() = #externalMacro(module: "TerminalUIComponentMacros", type: "TerminalComponentMacro")

@MainActor
package protocol PrimitiveView: TerminalView where Body == Never {
    func lower(path: [CompositionAddress]) -> [Element]
}

@MainActor
package struct ViewDescriptor<View: TerminalView>: ComponentDescriptor {
    package let value: View
    package init(value: View) {
        self.value = value
    }
    package var componentType: ObjectIdentifier { ObjectIdentifier(View.self) }
    package func body(context: AnyObject) -> Element {
        var installed = value
        installed._installState(StateInstallation(context: context as! MountContext))
        // Primitive reads belong to this component. Child bodies remain descriptors.
        if let primitive = installed as? any PrimitiveView { return rootElement(primitive.lower(path: [])) }
        return rootElement(lowerView(installed.body, path: []))
    }
}

@MainActor
package func lowerView<V: TerminalView>(_ view: V, path: [CompositionAddress] = []) -> [Element] {
    if let primitive = view as? any PrimitiveView { return primitive.lower(path: path) }
    var element = Element.component(ViewDescriptor(value: view))
    element.compositionPath = path
    return [element]
}

@MainActor
package func rootElement(_ elements: [Element]) -> Element {
    if elements.count == 1 { return elements[0] }
    return .column(elements)
}
