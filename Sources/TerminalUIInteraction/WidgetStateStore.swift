/// Transient state is keyed by control kind and ID; application values stay in Element.
package struct EditorState: Equatable {
    package var caret: Int?
    package var selection: Int?
    package var preferredColumn: Int?
}

package struct ViewportState: Equatable {
    package var offset: Int?
    package var height: Int?
    package var width: Int?
    package var limit: Int?
}

package struct WidgetState: Equatable {
    package var editor = EditorState()
    package var viewport = ViewportState()
    package var panelSize: Int?
}

/// Owns reset and bounded retention for every kind of transient control state.
package final class WidgetStateStore {
    package private(set) var manuallyScrolled: Set<String> = []
    private var entries: [String: WidgetState] = [:]
    private var inactiveOrder: [String] = []
    private let inactiveLimit: Int

    package init(inactiveLimit: Int = 256) {
        self.inactiveLimit = max(0, inactiveLimit)
    }

    package subscript(id: String) -> WidgetState {
        get { entries[id] ?? WidgetState() }
        set { entries[id] = newValue == WidgetState() ? nil : newValue }
    }

    package func resumeAutomaticVisibility() {
        manuallyScrolled.removeAll()
    }

    package func markManuallyScrolled(_ ids: Set<String>) {
        manuallyScrolled.formUnion(ids)
    }

    package func reset(id: String) {
        let keys = Set(["field:", "editor:", "list:", "table:", "scroll:", "panelResize:width:", "panelResize:height:"].map { $0 + id })
        for key in keys {
            entries.removeValue(forKey: key)
        }
        inactiveOrder.removeAll { keys.contains($0) }
        manuallyScrolled.subtract(keys)
    }

    package func evictInactive(excluding active: Set<String>) {
        manuallyScrolled.formIntersection(active)
        let stored = Set(entries.keys)
        inactiveOrder.removeAll { active.contains($0) || !stored.contains($0) }
        let known = Set(inactiveOrder)
        inactiveOrder.append(contentsOf: stored.subtracting(active).subtracting(known).sorted())
        while inactiveOrder.count > inactiveLimit {
            entries.removeValue(forKey: inactiveOrder.removeFirst())
        }
    }
}
