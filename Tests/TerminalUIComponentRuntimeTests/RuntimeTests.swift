@testable import TerminalUIComponentRuntime
import TerminalUICore
import Testing

@MainActor
struct RuntimeTests {
    @Test func `detached storage ignores writes and releases values`() {
        let driver = UpdateDriver(schedule: { _ in }, diagnostic: { _ in })
        let record = MountedComponent(identity: "owner", parent: nil)
        let context = MountContext(record: record, driver: driver)
        var initializations = 0
        var cell: StateSlot<String>? = context.install(key: "name", initial: { initializations += 1; return "initial" }, equals: ==)
        let reconnected: StateSlot<String> = context.install(key: "name", initial: { initializations += 1; return "wrong" }, equals: ==)
        #expect(initializations == 1)
        #expect(cell === reconnected)
        driver.evaluating = record
        #expect(cell?.read() == "initial")
        driver.evaluating = nil
        cell?.write("changed")
        #expect(driver.dirty == ["owner"])
        record.unmount(driver: driver)
        cell?.write("stale")
        #expect(cell?.read() == "changed")
        #expect(driver.dirty.isEmpty)
        cell = nil
        #expect(reconnected.read() == "changed")
    }

    @Test func `unmount releases record owned objects`() {
        final class Token {}
        let driver = UpdateDriver(schedule: { _ in }, diagnostic: { _ in })
        let record = MountedComponent(identity: "owner", parent: nil)
        let context = MountContext(record: record, driver: driver)
        weak var token: Token?
        do {
            let slot: StateSlot<Token> = context.install(key: "token", initial: { Token() }, equals: nil)
            token = slot.read()
        }
        #expect(token != nil)
        record.unmount(driver: driver)
        #expect(token == nil)
    }

    @Test func `mutation is rejected during body measurement and painting`() {
        var diagnostics: [String] = []
        let driver = UpdateDriver(schedule: { _ in }, diagnostic: { diagnostics.append($0) })
        let slot = StateSlot(0, driver: driver, equals: ==)
        for phase in ["component body evaluation", "measurement", "painting"] {
            UIEvaluationPhase.perform(phase) { slot.write(1) }
        }
        #expect(slot.read() == 0)
        #expect(diagnostics.count == 3)
        #expect(driver.metrics.stateWrites == 0)
    }
}
