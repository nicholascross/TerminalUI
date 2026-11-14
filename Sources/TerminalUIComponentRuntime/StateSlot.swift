import TerminalUICore

@MainActor
package protocol AnyStateSlot: AnyObject {
    var subscribers: Set<String> { get set }
    func detach()
}

/// A cell belongs to one mount generation. Retained bindings never reconnect it to a new mount.
@MainActor
package final class StateSlot<Value>: AnyStateSlot {
    private var value: Value
    private weak var driver: UpdateDriver?
    private var attached = true
    private let equals: ((Value, Value) -> Bool)?
    package var subscribers: Set<String> = []

    package init(_ value: Value, driver: UpdateDriver, equals: ((Value, Value) -> Bool)?) {
        self.value = value; self.driver = driver; self.equals = equals
    }

    package func read() -> Value {
        if attached, let record = driver?.evaluating {
            subscribers.insert(record.identity)
            record.dependencies[ObjectIdentifier(self)] = self
        }
        return value
    }

    package func write(_ next: Value) {
        guard attached else {
            driver?.diagnostic("Ignored state write from an unmounted component generation")
            return
        }
        guard driver?.evaluating == nil, UIEvaluationPhase.current == nil else {
            driver?.diagnostic("State mutation during \(UIEvaluationPhase.current ?? "component body evaluation") is not allowed")
            return
        }
        if equals?(value, next) == true { return }
        value = next
        driver?.changed(subscribers)
    }

    package func detach() {
        attached = false; subscribers.removeAll()
    }
}

@MainActor
package final class MountContext {
    private unowned let record: MountedComponent
    private unowned let driver: UpdateDriver
    package init(record: MountedComponent, driver: UpdateDriver) {
        self.record = record; self.driver = driver
    }

    package func install<Value>(key: String, initial: () -> Value, equals: ((Value, Value) -> Bool)?) -> StateSlot<Value> {
        if let old = record.state[key] {
            guard let typed = old as? StateSlot<Value> else {
                preconditionFailure("State declaration '\(key)' changed its value type within a mounted component")
            }
            return typed
        }
        let slot = StateSlot(initial(), driver: driver, equals: equals)
        record.state[key] = slot
        return slot
    }
}
