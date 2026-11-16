import TerminalUICore

extension TerminalView {
    /// Activates a button anywhere in the active workspace or dialog scope.
    /// Accepts Alt/Control printable ASCII characters and Control-C/D/P; the first matching binding wins.
    /// Unsupported events fail a precondition when the modifier is declared.
    @MainActor public func keyboardShortcut(_ key: KeyEvent) -> ModifiedView<Self> {
        let key = key.validatedGlobalShortcut()
        return ModifiedView(content: self, deferToBody: true) { element in
            guard case .button(let title, let id) = element.kind else {
                preconditionFailure("keyboardShortcut requires a button")
            }
            var value = element
            value.menuShortcutItems.append(MenuItem(id: id, title: title, globalShortcuts: [key]))
            return value
        }
    }

    /// Prefers this control when the screen or a modal first receives focus.
    /// Later updates preserve the user's focus. With several preferences, the first visible enabled control wins.
    @MainActor public func initialFocus(_ preferred: Bool = true) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            precondition(element.controlID != nil, "initialFocus requires a focusable control")
            var value = element
            value.prefersInitialFocus = preferred
            return value
        }
    }

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

    /// Registers a control callback. On collection menus, observes accepted activation before
    /// the default focus action or explicit item callback, without replacing that action.
    @MainActor public func onActivate(_ action: @escaping @MainActor () -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            if element.isCollectionMenu {
                var value = element
                value.menuActivationObservers.append(action)
                return value
            }
            guard let id = element.controlID else { preconditionFailure("onActivate requires a control") }
            var value = element
            value.behaviors.removeAll { $0.event == .activate }
            value.behaviors.append(ElementBehavior(.activate, id: id) { _ in action() })
            return value
        }
    }

    /// Handles Escape and any built-in dismissal button, including a menu's Return button.
    @MainActor public func onDismiss(_ action: @escaping @MainActor () -> Void) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            guard case .dialog(let id, _, _) = element.kind else { preconditionFailure("onDismiss requires a dialog") }
            var value = element
            value.behaviors.removeAll {
                $0.event == .dismiss || ($0.event == .activate && $0.controlID == element.dismissalButtonID)
            }
            value.behaviors.append(ElementBehavior(.dismiss, id: id) { _ in action() })
            if let buttonID = element.dismissalButtonID {
                value.behaviors.append(ElementBehavior(.activate, id: buttonID) { _ in action() })
            }
            return value
        }
    }
}
