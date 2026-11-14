/// A synchronous connection to authoritative state. Setters may normalize or reject proposed values.
@MainActor
@propertyWrapper
@dynamicMemberLookup
public struct Binding<Value> {
    package var tracksState = false
    private let getValue: () -> Value
    private let setValue: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) {
        getValue = get; setValue = set
    }

    public var wrappedValue: Value {
        get { getValue() }
        nonmutating set { setValue(newValue) }
    }

    public var projectedValue: Binding<Value> {
        self
    }

    public static func constant(_ value: Value) -> Binding<Value> {
        var binding = Binding(get: { value }, set: { _ in })
        binding.tracksState = true
        return binding
    }

    public subscript<Member>(dynamicMember path: WritableKeyPath<Value, Member>) -> Binding<Member> {
        var binding = Binding<Member>(get: { wrappedValue[keyPath: path] }, set: { next in
            var value = wrappedValue
            value[keyPath: path] = next
            wrappedValue = value
        })
        binding.tracksState = tracksState
        return binding
    }
}
