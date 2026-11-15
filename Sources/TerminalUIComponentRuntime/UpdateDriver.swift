import TerminalUICore

@MainActor
package final class UpdateDriver {
    package typealias Scheduler = @MainActor (@escaping @MainActor () -> Void) -> Void
    package var schedule: Scheduler
    package var wake: () -> Void = {}
    package var dirty: Set<String> = []
    package var evaluating: MountedComponent?
    package weak var applicationServices: (any ApplicationServices)?
    package var pending = false
    package var transactionDepth = 0
    package var metrics = ComponentMetrics()
    package var diagnostic: @MainActor (String) -> Void
    private var deferredRequest = false
    private var ticket: UInt64 = 0

    package init(schedule: @escaping Scheduler, diagnostic: @escaping @MainActor (String) -> Void) {
        self.schedule = schedule
        self.diagnostic = diagnostic
    }

    package func changed(_ subscribers: Set<String>) {
        metrics.stateWrites += 1
        dirty.formUnion(subscribers)
        guard !subscribers.isEmpty else { return }
        requestFlush()
    }

    package func requestFlush() {
        if transactionDepth > 0 {
            deferredRequest = true
            return
        }
        guard !pending else { return }
        pending = true
        ticket &+= 1
        let current = ticket
        metrics.scheduledFlushes += 1
        schedule { [weak self] in
            guard let self, pending, ticket == current else { return }
            wake()
        }
    }

    package func consume() {
        pending = false
        ticket &+= 1
    }

    package func transaction<Result>(_ work: () throws -> Result) rethrows -> Result {
        transactionDepth += 1
        defer {
            transactionDepth -= 1
            if transactionDepth == 0, deferredRequest || !dirty.isEmpty {
                deferredRequest = false
                requestFlush()
            }
        }
        return try work()
    }
}

/// Counts distinct kinds of component work; terminal painting/output are measured separately.
public struct ComponentMetrics: Equatable, Sendable {
    public package(set) var mounts = 0
    public package(set) var unmounts = 0
    public package(set) var stateWrites = 0
    public package(set) var scheduledFlushes = 0
    public package(set) var bodyEvaluations = 0
    public package(set) var componentReconciliations = 0
    public init() {}
}
