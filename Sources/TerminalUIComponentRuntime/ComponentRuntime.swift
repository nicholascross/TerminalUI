import Foundation
import TerminalUICore

package struct LocalIdentity: Hashable {
    package enum Key: Hashable { case explicit(AnyHashable), structural([Int]) }
    package let key: Key
    package let type: ObjectIdentifier
}

@MainActor
package final class MountedComponent {
    package let identity: String
    package weak var parent: MountedComponent?
    package var descriptor: (any ComponentDescriptor)?
    package var envelope: Element = .spacer()
    package var state: [String: any AnyStateSlot] = [:]
    package var dependencies: [ObjectIdentifier: any AnyStateSlot] = [:]
    package var children: [LocalIdentity: MountedComponent] = [:]
    package var orderedChildren: [MountedComponent] = []
    package var content: Element = .spacer()
    package var output: Element = .spacer()
    package var revision: UInt64 = 0
    package var bodyRevision: UInt64 = 0
    package var registrations: [BehaviorAddress: ElementBehavior] = [:]
    package var actionHandlers: [@MainActor (UIAction) -> Bool] = []
    package var localIDs: [String: String] = [:]
    package var actionIDs: [String: String] = [:]

    package init(identity: String, parent: MountedComponent?, descriptor: (any ComponentDescriptor)? = nil) {
        self.identity = identity; self.parent = parent; self.descriptor = descriptor
    }

    package func unsubscribe() {
        for slot in dependencies.values {
            slot.subscribers.remove(identity)
        }
        dependencies.removeAll()
    }

    package func unmount(driver: UpdateDriver) {
        driver.dirty.remove(identity)
        unsubscribe()
        for slot in state.values {
            slot.detach()
        }
        state.removeAll()
        for child in orderedChildren {
            child.unmount(driver: driver)
        }
        children.removeAll(); orderedChildren.removeAll()
        registrations.removeAll(); actionHandlers.removeAll(); localIDs.removeAll(); actionIDs.removeAll()
        content = .spacer(); output = .spacer()
    }
}

package struct BehaviorAddress: Hashable {
    package let event: ElementBehaviorEvent
    package let id: String
}

/// A terminal-independent mounted tree, dependency tracker and synchronous consistency barrier.
@MainActor
package final class ComponentRuntime {
    private let root = MountedComponent(identity: UUID().uuidString, parent: nil)
    private let makeRoot: () -> Element
    package let driver: UpdateDriver
    private var initialized = false
    private var generation: UInt64 = 0
    package private(set) var revision: UInt64 = 0
    package var hasPendingUpdates: Bool {
        !initialized || !driver.dirty.isEmpty
    }

    package var metrics: ComponentMetrics {
        driver.metrics
    }

    package init(
        makeRoot: @escaping () -> Element,
        schedule: @escaping UpdateDriver.Scheduler,
        diagnostic: @escaping @MainActor (String) -> Void,
    ) {
        self.makeRoot = makeRoot
        driver = UpdateDriver(schedule: schedule, diagnostic: diagnostic)
    }

    package func connect(_ services: PresentationServices) {
        driver.wake = services.requestUpdate
    }

    package func resolve(invalidateRoot: Bool = false) -> Element {
        // Transactions defer resolution as well as scheduled output.
        if driver.transactionDepth > 0, initialized { return root.output }
        driver.consume()
        if invalidateRoot || !initialized {
            evaluate(root)
            initialized = true
            revision &+= 1
        } else if refresh(root) {
            revision &+= 1
        }
        return root.output
    }

    private func evaluate(_ record: MountedComponent) {
        record.unsubscribe()
        record.registrations.removeAll(); record.actionHandlers.removeAll(); record.localIDs.removeAll(); record.actionIDs.removeAll()
        driver.dirty.remove(record.identity)
        let raw: Element
        if let descriptor = record.descriptor {
            driver.metrics.bodyEvaluations += 1
            driver.evaluating = record
            raw = UIEvaluationPhase.perform("component body evaluation") {
                descriptor.body(context: MountContext(record: record, driver: driver))
            }
            driver.evaluating = nil
        } else {
            raw = makeRoot()
        }
        var nextChildren: [LocalIdentity: MountedComponent] = [:]
        var order: [MountedComponent] = []
        var keys: Set<AnyHashable> = []
        record.content = mount(raw, owner: record, path: [], next: &nextChildren, order: &order, keys: &keys)
        for (id, old) in record.children where nextChildren[id] == nil {
            old.unmount(driver: driver)
        }
        record.children = nextChildren
        record.orderedChildren = order
        record.bodyRevision &+= 1
        revise(record)
    }

    private func mount(
        _ element: Element,
        owner: MountedComponent,
        path: [Int],
        next: inout [LocalIdentity: MountedComponent],
        order: inout [MountedComponent],
        keys: inout Set<AnyHashable>,
    ) -> Element {
        if case let .component(descriptor) = element.kind {
            if let key = descriptor.key {
                precondition(keys.insert(key).inserted, "Duplicate sibling component key '\(key)'")
            }
            let local = LocalIdentity(key: descriptor.key.map { .explicit($0) } ?? .structural(path), type: descriptor.componentType)
            let child: MountedComponent
            if let old = owner.children[local] { child = old } else {
                generation &+= 1
                child = MountedComponent(identity: root.identity + "/" + String(generation), parent: owner, descriptor: descriptor)
            }
            driver.metrics.componentReconciliations += 1
            child.descriptor = descriptor
            child.envelope = element
            next[local] = child
            order.append(child)
            // New input values and callbacks always replace old captures.
            evaluate(child)
            return child.output
        }
        var value = scope(element, owner: owner)
        value = value.replacingChildren(element.children.enumerated().map { index, child in
            mount(child, owner: owner, path: path + [index], next: &next, order: &order, keys: &keys)
        })
        return value
    }

    @discardableResult
    private func refresh(_ record: MountedComponent) -> Bool {
        if driver.dirty.contains(record.identity) { evaluate(record); return true }
        var replacements: [String: Element] = [:]
        for child in record.orderedChildren where refresh(child) {
            replacements[child.identity] = child.output
        }
        guard !replacements.isEmpty else { return false }
        func replace(_ value: Element) -> Element {
            if case let .boundary(boundary, _) = value.kind { return replacements[boundary.identity] ?? value }
            return value.replacingChildren(value.children.map(replace))
        }
        record.content = replace(record.content)
        revise(record)
        return true
    }

    private func revise(_ record: MountedComponent) {
        record.revision &+= 1
        if record.descriptor == nil { record.output = record.content } else {
            record.output = record.envelope.resolvedBoundary(.init(identity: record.identity, revision: record.revision), body: record.content)
        }
    }

    package func focusDidChange(_ target: ScopedFocusTarget?) {
        let address = BehaviorAddress(event: .focus, id: "")
        func handlers(_ record: MountedComponent) -> [ElementBehavior] {
            let own = record.registrations[address].map { [$0] } ?? []
            return own + record.orderedChildren.flatMap(handlers)
        }
        // A callback may resolve new output. Snapshot registrations before delivering it.
        for handler in handlers(root) { handler.invoke(target?.engineID) }
    }

    package func handle(_ action: UIAction) -> Bool {
        let event: ElementBehaviorEvent
        let id: String
        let payload: String?
        switch action {
        case let .textChanged(control, value): event = .text; id = control; payload = value
        case let .selectionChanged(control, value): event = .selection; id = control; payload = value
        case let .activated(control): event = .activate; id = control; payload = nil
        case let .dismissRequested(control): event = .dismiss; id = control; payload = nil
        default: return dispatchFallback(action, id: nil)
        }
        func dispatch(_ record: MountedComponent) -> Bool {
            if let handler = record.registrations[BehaviorAddress(event: event, id: id)] {
                handler.invoke(payload)
                if handler.requiresRefresh { driver.dirty.insert(record.identity); driver.requestFlush() }
                return true
            }
            return record.orderedChildren.contains(where: dispatch)
        }
        if dispatch(root) { return true }
        return dispatchFallback(action, id: id)
    }

    private func dispatchFallback(_ action: UIAction, id: String?) -> Bool {
        func owner(_ record: MountedComponent) -> MountedComponent? {
            if let id, record.actionIDs[id] != nil { return record }
            return record.orderedChildren.lazy.compactMap { owner($0) }.first
        }
        var record: MountedComponent? = owner(root) ?? (root.orderedChildren.count == 1 ? root.orderedChildren.first : root)
        let local = unscoped(action)
        while let current = record {
            if current.actionHandlers.reversed().contains(where: { $0(local) }) { return true }
            record = current.parent
        }
        return false
    }

    package func unscoped(_ action: UIAction) -> UIAction {
        var ids: [String: String] = [:]
        func collect(_ record: MountedComponent) {
            ids.merge(record.actionIDs) { _, new in new }
            for child in record.orderedChildren {
                collect(child)
            }
        }
        collect(root)
        switch action {
        case let .textChanged(id, value): return .textChanged(ids[id] ?? id, value)
        case let .selectionChanged(id, value): return .selectionChanged(ids[id] ?? id, value)
        case let .activated(id): return .activated(ids[id] ?? id)
        case let .dismissRequested(id): return .dismissRequested(ids[id] ?? id)
        default: return action
        }
    }

    package func focusTarget(path: [AnyHashable], id: String) -> ScopedFocusTarget? {
        var record = root
        if root.orderedChildren.count == 1, let child = root.orderedChildren.first, child.descriptor?.key == nil { record = child }
        for key in path {
            guard let child = record.orderedChildren.first(where: { $0.descriptor?.key == key }) else { return nil }
            record = child
        }
        return record.localIDs[id].map { ScopedFocusTarget(engineID: $0) }
    }

    package func unmount() {
        root.unmount(driver: driver); driver.dirty.removeAll(); driver.consume(); initialized = false
    }
}
