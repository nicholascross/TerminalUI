import Foundation
import TerminalUICore

package struct LocalIdentity: Hashable {
    package enum Key: Hashable {
        case explicit(AnyHashable)
        case structural([CompositionAddress])
    }
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
        self.identity = identity
        self.parent = parent
        self.descriptor = descriptor
    }

    package func unsubscribe() {
        for slot in dependencies.values {
            slot.subscribers.remove(identity)
        }
        dependencies.removeAll()
    }

    package func unmount(driver: UpdateDriver) {
        if descriptor != nil { driver.metrics.unmounts += 1 }
        driver.dirty.remove(identity)
        unsubscribe()
        for slot in state.values {
            slot.detach()
        }
        state.removeAll()
        for child in orderedChildren {
            child.unmount(driver: driver)
        }
        children.removeAll()
        orderedChildren.removeAll()
        registrations.removeAll()
        actionHandlers.removeAll()
        localIDs.removeAll()
        actionIDs.removeAll()
        content = .spacer()
        output = .spacer()
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
        record.registrations.removeAll()
        record.actionHandlers.removeAll()
        record.localIDs.removeAll()
        record.actionIDs.removeAll()
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
            driver.evaluating = record
            raw = UIEvaluationPhase.perform("component body evaluation") { makeRoot() }
            driver.evaluating = nil
        }
        var nextChildren: [LocalIdentity: MountedComponent] = [:]
        var order: [MountedComponent] = []
        var keys: Set<AnyHashable> = []
        let decorated = record.envelope.deferredModifiers.reduce(raw) { $0.applyingDeferredModifier($1) }
        record.content = mount(decorated, owner: record, path: [], next: &nextChildren, order: &order, keys: &keys)
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
        path: [CompositionAddress],
        next: inout [LocalIdentity: MountedComponent],
        order: inout [MountedComponent],
        keys: inout Set<AnyHashable>,
    ) -> Element {
        let path = element.compositionPath ?? path
        if case .component(let descriptor) = element.kind {
            if let key = descriptor.key, element.compositionPath == nil {
                precondition(keys.insert(key).inserted, "Duplicate sibling component key '\(key)'")
            }
            let local = LocalIdentity(
                key: element.compositionPath != nil ? .structural(path) : descriptor.key.map { .explicit($0) } ?? .structural(path),
                type: descriptor.componentType)
            let child: MountedComponent
            if let old = owner.children[local] {
                child = old
            } else {
                generation &+= 1
                driver.metrics.mounts += 1
                child = MountedComponent(identity: root.identity + "/" + String(generation), parent: owner, descriptor: descriptor)
            }
            driver.metrics.componentReconciliations += 1
            child.descriptor = descriptor
            child.envelope = element
            if element.viewID != nil { child.envelope.visibilityID = child.identity + "/@view" }
            next[local] = child
            order.append(child)
            // New input values and callbacks always replace old captures.
            evaluate(child)
            return child.output
        }
        var value = scope(element, owner: owner)
        value = value.replacingChildren(
            element.children.enumerated().map { index, child in
                mount(child, owner: owner, path: path + [.slot(index)], next: &next, order: &order, keys: &keys)
            })
        return value
    }

    @discardableResult
    private func refresh(_ record: MountedComponent) -> Bool {
        if driver.dirty.contains(record.identity) {
            evaluate(record)
            return true
        }
        var replacements: [String: Element] = [:]
        for child in record.orderedChildren where refresh(child) {
            replacements[child.identity] = child.output
        }
        guard !replacements.isEmpty else { return false }
        func replace(_ value: Element) -> Element {
            if case .boundary(let boundary, _) = value.kind { return replacements[boundary.identity] ?? value }
            return value.replacingChildren(value.children.map(replace))
        }
        record.content = replace(record.content)
        revise(record)
        return true
    }

    private func revise(_ record: MountedComponent) {
        record.revision &+= 1
        if record.descriptor == nil {
            record.output = record.content
        } else {
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
        case .textChanged(let control, let value):
            event = .text
            id = control
            payload = value
        case .selectionChanged(let control, let value):
            event = .selection
            id = control
            payload = value
        case .activated(let control):
            event = .activate
            id = control
            payload = nil
        case .dismissRequested(let control):
            event = .dismiss
            id = control
            payload = nil
        default: return dispatchFallback(action, id: nil)
        }
        func dispatch(_ record: MountedComponent) -> Bool {
            if let handler = record.registrations[BehaviorAddress(event: event, id: id)] {
                handler.invoke(payload)
                if handler.requiresRefresh {
                    driver.dirty.insert(record.identity)
                    driver.requestFlush()
                }
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
        case .textChanged(let id, let value): return .textChanged(ids[id] ?? id, value)
        case .selectionChanged(let id, let value): return .selectionChanged(ids[id] ?? id, value)
        case .activated(let id): return .activated(ids[id] ?? id)
        case .dismissRequested(let id): return .dismissRequested(ids[id] ?? id)
        default: return action
        }
    }

    private func records(from start: MountedComponent) -> [MountedComponent] {
        [start] + start.orderedChildren.flatMap { records(from: $0) }
    }

    private func lookupRoot(_ scope: ViewScope?) -> MountedComponent? {
        if let scope { return records(from: root).first { $0.identity == scope.identity } }
        if root.orderedChildren.count == 1 { return root.orderedChildren.first }
        return root
    }

    package func scope(id: AnyHashable, in parent: ViewScope?) -> ViewScope? {
        guard let start = lookupRoot(parent) else { return nil }
        let matches = records(from: start).filter { $0.envelope.scopeID == id }
        guard matches.count <= 1 else {
            driver.diagnostic("Ambiguous view scope")
            return nil
        }
        return matches.first.map { ViewScope(identity: $0.identity) }
    }

    package func focusTarget(path: [AnyHashable], id: String, in scope: ViewScope? = nil) -> ScopedFocusTarget? {
        guard var record = lookupRoot(scope) else { return nil }
        func keyedChildren(_ record: MountedComponent) -> [MountedComponent] {
            record.orderedChildren.flatMap { child in
                child.descriptor?.key == nil ? keyedChildren(child) : [child]
            }
        }
        for key in path {
            let matches = keyedChildren(record).filter { $0.descriptor?.key == key }
            guard matches.count <= 1 else {
                driver.diagnostic("Ambiguous component key path")
                return nil
            }
            guard let child = matches.first else { return nil }
            record = child
        }
        func controls(_ record: MountedComponent) -> [String] {
            let own = record.localIDs[id].map { [$0] } ?? []
            return own + record.orderedChildren.filter { $0.descriptor?.key == nil }.flatMap(controls)
        }
        let matches = controls(record)
        guard matches.count <= 1 else {
            driver.diagnostic("Ambiguous focus target")
            return nil
        }
        return matches.first.map { ScopedFocusTarget(engineID: $0) }
    }

    package func revealTarget(id: AnyHashable, in scope: ViewScope?) -> String? {
        guard let start = lookupRoot(scope) else { return nil }
        let matches = records(from: start).filter { $0.envelope.viewID == id }
        guard matches.count <= 1 else {
            driver.diagnostic("Ambiguous reveal target")
            return nil
        }
        guard let record = matches.first else { return nil }
        // Visibility on any primitive ancestor, including one outside the selected scope, applies.
        func visibleID(_ element: Element, visible: Bool) -> Bool {
            let visible = visible && element.isVisible
            if element.visibilityID == record.identity + "/@view" { return visible }
            return element.children.contains { visibleID($0, visible: visible) }
        }
        return visibleID(root.output, visible: true) ? record.identity + "/@view" : nil
    }

    package func unmount() {
        root.unmount(driver: driver)
        driver.dirty.removeAll()
        driver.consume()
        initialized = false
    }
}
