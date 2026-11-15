import TerminalUICore

extension TerminalView {
    /// Registers a semantic focus destination on a control without depending on its view path.
    /// The registration follows the control's mounted lifetime; values retain their concrete type.
    public func focusTarget<Value: Hashable>(_ value: Value) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { element in
            precondition(element.controlID != nil, "focusTarget requires a focusable control")
            var result = element
            result.focusValue = ViewID(value)
            return result
        }
    }

    /// Observes registered values in this subtree. Reports nil when focus leaves its typed targets.
    /// Delivery occurs outside view evaluation, so callbacks may write state or request focus.
    public func onFocusChange<Value: Hashable>(
        of type: Value.Type, _ action: @escaping @MainActor (Value?) -> Void
    ) -> some TerminalView {
        FocusObservationScope(content: self, action: action)
    }
}

/// Gives the observation its own mounted subtree even when content is a primitive container.
private struct FocusObservationScope<Content: TerminalView, Value: Hashable>: TerminalView {
    let content: Content
    let action: @MainActor (Value?) -> Void

    var body: some TerminalView {
        ModifiedView(content: content) { element in
            var result = element
            let valueType = ObjectIdentifier(Value.self)
            result.focusValueObservers.removeAll { $0.valueType == valueType }
            result.focusValueObservers.append(FocusValueObserver(valueType: valueType) { value in
                action(value?.base as? Value)
            })
            return result
        }
    }
}
