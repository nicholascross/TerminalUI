package enum CompositionAddress: Hashable {
    case slot(Int)
    case branch(Int)
    case position(Int)
    case key(AnyHashable)
}

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
        self.identity = identity
        self.revision = revision
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
        self.event = event
        controlID = id
        self.invoke = invoke
    }
}

extension Element {
    package static func component(_ descriptor: any ComponentDescriptor) -> Element {
        .init(kind: .component(descriptor))
    }

    /// Rebuilds only container paths; all appearance and behavior metadata stays on the original value.
    package func replacingChildren(_ children: [Element]) -> Element {
        var copy = self
        switch kind {
        case .column(let spacing, _): copy.kind = .column(spacing, children)
        case .row(let spacing, _): copy.kind = .row(spacing, children)
        case .layout(let strategy, _): copy.kind = .layout(strategy, children)
        case .panel(let title, _): copy.kind = .panel(title, children[0])
        case .dialog(let id, let title, _): copy.kind = .dialog(id, title, children[0])
        case .scroll(let id, _): copy.kind = .scroll(id, children[0])
        case .overlay: copy.kind = .overlay(children[0], children[1])
        case .boundary(let boundary, _): copy.kind = .boundary(boundary, children[0])
        default: break
        }
        return copy
    }

    package func resolvedBoundary(_ boundary: ComponentBoundary, body: Element) -> Element {
        var copy = self
        copy.kind = .boundary(boundary, body)
        if !hasExplicitWidth { copy.widthRule = body.widthRule }
        if !hasExplicitHeight { copy.heightRule = body.heightRule }
        return copy
    }
}

/// Preserve both value equality and the identifier's concrete type through erasure.
package struct ViewID: Hashable {
    package let type: ObjectIdentifier
    package let value: AnyHashable
    package init<ID: Hashable>(_ id: ID) {
        type = ObjectIdentifier(ID.self)
        value = AnyHashable(id)
    }
}

extension Element {
    @MainActor package func applyingDeferredModifier(_ transform: @escaping @MainActor (Element) -> Element) -> Element {
        if case .component = kind {
            var copy = self
            copy.deferredModifiers.append(transform)
            return copy
        }
        return transform(self)
    }
}
