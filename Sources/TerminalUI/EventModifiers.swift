import TerminalUICore

extension TerminalView {
    /// Observes host focus changes through generation-scoped handles. Writes may update local state.
    @MainActor public func onFocusChange(_ action: @escaping @MainActor (ScopedFocusTarget?) -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            var value = element
            value.behaviors.removeAll { $0.event == .focus }
            value.behaviors.append(
                ElementBehavior(.focus, id: "") { id in
                    action(id.map { ScopedFocusTarget(engineID: $0) })
                })
            return value
        }
    }

    /// Handles an otherwise unclaimed action in this mounted scope. Return true to consume it.
    @MainActor public func onAction(_ handler: @escaping @MainActor (UIAction) -> Bool) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            var value = element
            value.actionHandlers.append(handler)
            return value
        }
    }

    @MainActor public func onSubmit(_ action: @escaping @MainActor () -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            guard let id = element.controlID else { preconditionFailure("onSubmit requires a control") }
            var value = element
            value.behaviors.removeAll { $0.event == .submit }
            value.behaviors.append(ElementBehavior(.submit, id: id) { _ in action() })
            return value
        }
    }

    @MainActor public func onActivate(_ action: @escaping @MainActor () -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            guard let id = element.controlID else { preconditionFailure("onActivate requires a control") }
            var value = element
            value.behaviors.removeAll { $0.event == .activate }
            value.behaviors.append(ElementBehavior(.activate, id: id) { _ in action() })
            return value
        }
    }

    @MainActor public func onDismiss(_ action: @escaping @MainActor () -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            guard case .dialog(let id, _, _) = element.kind else { preconditionFailure("onDismiss requires a dialog") }
            var value = element
            value.behaviors.removeAll { $0.event == .dismiss }
            value.behaviors.append(ElementBehavior(.dismiss, id: id) { _ in action() })
            return value
        }
    }
}
