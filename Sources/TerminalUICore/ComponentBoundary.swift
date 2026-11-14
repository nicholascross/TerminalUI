/// Erased, unevaluated component input. Only the optional runtime opens this descriptor.
@MainActor
package protocol ComponentDescriptor {
    var componentType: ObjectIdentifier { get }
    var key: AnyHashable? { get }
    func body(context: AnyObject) -> Element
}

package struct ComponentBoundary: Equatable {
    package let identity: String
    package let revision: UInt64
    package init(identity: String, revision: UInt64) {
        self.identity = identity; self.revision = revision
    }
}

package enum ElementBehaviorEvent: Hashable {
    case text, selection, submit, activate, dismiss, focus
}

package struct ElementBehavior {
    package let event: ElementBehaviorEvent
    package let controlID: String
    package var requiresRefresh = false
    package let invoke: @MainActor (String?) -> Void
    package init(_ event: ElementBehaviorEvent, id: String, invoke: @escaping @MainActor (String?) -> Void) {
        self.event = event; controlID = id; self.invoke = invoke
    }
}

package extension Element {
    static func component(_ descriptor: any ComponentDescriptor) -> Element {
        .init(kind: .component(descriptor))
    }

    /// Rebuilds only container paths; all appearance and behavior metadata stays on the original value.
    func replacingChildren(_ children: [Element]) -> Element {
        var copy = self
        switch kind {
        case let .column(spacing, _): copy.kind = .column(spacing, children)
        case let .row(spacing, _): copy.kind = .row(spacing, children)
        case let .layout(strategy, _): copy.kind = .layout(strategy, children)
        case let .panel(title, _): copy.kind = .panel(title, children[0])
        case let .dialog(id, title, _): copy.kind = .dialog(id, title, children[0])
        case let .scroll(id, _): copy.kind = .scroll(id, children[0])
        case .overlay: copy.kind = .overlay(children[0], children[1])
        case let .boundary(boundary, _): copy.kind = .boundary(boundary, children[0])
        default: break
        }
        return copy
    }

    func resolvedBoundary(_ boundary: ComponentBoundary, body: Element) -> Element {
        var copy = self
        copy.kind = .boundary(boundary, body)
        if !hasExplicitWidth { copy.widthRule = body.widthRule }
        if !hasExplicitHeight { copy.heightRule = body.heightRule }
        return copy
    }
}
