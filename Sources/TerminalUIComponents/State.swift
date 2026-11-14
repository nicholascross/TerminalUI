import TerminalUIComponentRuntime

/// Public implementation support used by macro expansions in external modules.
@MainActor
public struct StateInstallation {
    package let context: MountContext
    package init(context: MountContext) {
        self.context = context
    }
}

@MainActor
@propertyWrapper
public struct State<Value> {
    private let initial: () -> Value
    private let equals: ((Value, Value) -> Bool)?
    private var slot: StateSlot<Value>?

    public init(wrappedValue: @autoclosure @escaping () -> Value) {
        initial = wrappedValue
        // Runtime opening preserves Equatable suppression even through generic declarations.
        equals = { lhs, rhs in
            guard let equatable = lhs as? any Equatable else { return false }
            return equatable._componentEquals(rhs)
        }
    }

    public var wrappedValue: Value {
        get {
            guard let slot else { preconditionFailure("@State must be installed by @TerminalComponent before reading its value") }
            return slot.read()
        }
        nonmutating set {
            guard let slot else { preconditionFailure("@State must be installed by @TerminalComponent before writing its value") }
            slot.write(newValue)
        }
    }

    public var projectedValue: Binding<Value> {
        var binding = Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
        binding.tracksState = true
        return binding
    }

    public mutating func _install(in installation: StateInstallation, key: String) {
        slot = installation.context.install(key: key, initial: initial, equals: equals)
    }
}

private extension Equatable {
    func _componentEquals(_ other: Any) -> Bool {
        (other as? Self).map { self == $0 } ?? false
    }
}
