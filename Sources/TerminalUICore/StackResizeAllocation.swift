/// Size preferences for the panels that opted in, indexed by visible stack child.
package struct StackPanelResize: Equatable {
    let stateKey: String
    let edge: PanelResizeEdge
    package let limits: ClosedRange<Int>
    package var preferred: Int?

    package init?(panel: PanelResize, policy: LayoutPreference, decoration: Int, preferred: Int?) {
        if case .fixed = policy { return nil }
        let lower = max(panel.minimum, decoration, policy.minimumCells)
        let upper = min(panel.maximum, policy.maximumCells)
        guard lower <= upper else { return nil }
        stateKey = panel.stateKey
        edge = panel.edge
        limits = lower ... upper
        self.preferred = preferred ?? panel.preferredSize
    }
}

/// One feasible allocation, shared by placement and by the drag that starts on it.
package struct StackResizeAllocation {
    package struct Contract: Equatable {
        let budget: Int
        let baseline: [Int]
        let policies: [LayoutPreference]
        var panels: [Int: StackPanelResize]
    }

    package private(set) var contract: Contract
    package private(set) var sizes: [Int]

    init(budget: Int, baseline: [Int], policies: [LayoutPreference], panels: [Int: StackPanelResize]) {
        contract = Contract(budget: budget, baseline: baseline, policies: policies, panels: panels)
        sizes = baseline
    }

    package func travel(for index: Int) -> ClosedRange<Int>? {
        guard let resize = contract.panels[index] else { return nil }
        let peers = adjustablePeers(of: index, edge: resize.edge)
        let canShrink = peers.reduce(0) { $0 + sizes[$1] - contract.policies[$1].minimumCells }
        let canGrow = peers.reduce(0) { $0 + contract.policies[$1].maximumCells - sizes[$1] }
        let size = sizes[index]
        let usesSpare = canUseSpare(at: index, edge: resize.edge)
        let lower = usesSpare ? resize.limits.lowerBound : max(resize.limits.lowerBound, size - canGrow)
        let upper = min(resize.limits.upperBound, size + canShrink + (usesSpare ? spareCells : 0))
        return lower ... upper
    }

    mutating func applyPreferences() {
        guard contract.panels.values.contains(where: { $0.preferred != nil }) else { return }
        var limits = sizes.indices.map { index -> ClosedRange<Int> in
            if let panel = contract.panels[index] { return panel.limits }
            if case .flexible = contract.policies[index] {
                return contract.policies[index].minimumCells ... contract.policies[index].maximumCells
            }
            return sizes[index] ... sizes[index]
        }
        var minimum = limits.reduce(0) { $0 + $1.lowerBound }
        var maximum = limits.reduce(0) { $0 + $1.upperBound }
        let canLeaveSpare = spareCells > 0 || contract.panels[sizes.count - 1]?.edge.isEnd == true
        let required = canLeaveSpare ? 0 : contract.budget

        // A fresh layout can satisfy preferences on both sides. Only a live drag has an anchored edge.
        for index in contract.panels.keys.sorted() {
            guard let preferred = contract.panels[index]?.preferred else { continue }
            let range = limits[index]
            minimum -= range.lowerBound
            maximum -= range.upperBound
            let lower = max(range.lowerBound, required - maximum)
            let upper = min(range.upperBound, contract.budget - minimum)
            let size = min(upper, max(lower, preferred))
            limits[index] = size ... size
            minimum += size
            maximum += size
        }
        sizes = zip(sizes, limits).map { min($1.upperBound, max($1.lowerBound, $0)) }
        if spareCells < 0 {
            shrink(sizes.indices, by: -spareCells) { limits[$0].lowerBound }
        } else {
            let flexible = sizes.indices.filter { if case .flexible = contract.policies[$0] { true } else { false } }
            let policies = sizes.indices.map { index -> LayoutPreference in
                let weight = if case let .flexible(_, _, value) = contract.policies[index] { value } else { 1 }
                return .flexible(minimum: limits[index].lowerBound, maximum: limits[index].upperBound, weight: weight)
            }
            StackLayout.expand(&sizes, policies: policies, remaining: spareCells, eligible: flexible)
            StackLayout.expand(&sizes, policies: policies, remaining: required - sizes.reduce(0, +), eligible: Array(sizes.indices))
        }
    }

    package mutating func resize(_ index: Int, to requested: Int) {
        guard let edge = contract.panels[index]?.edge, let range = travel(for: index) else { return }
        let size = min(range.upperBound, max(range.lowerBound, requested))
        let delta = size - sizes[index]
        guard delta != 0 else { return }
        let peers = adjustablePeers(of: index, edge: edge)
        let spare = canUseSpare(at: index, edge: edge) ? spareCells : 0
        sizes[index] = size
        if delta > 0 {
            let policies = contract.policies
            shrink(peers, by: max(0, delta - spare)) { policies[$0].minimumCells }
        } else if !peers.isEmpty {
            StackLayout.expand(&sizes, policies: contract.policies, remaining: -delta, eligible: peers)
        }
    }

    private mutating func shrink(_ indices: some Collection<Int>, by amount: Int, minimum: (Int) -> Int) {
        guard amount > 0 else { return }
        var demand = amount
        var capacity = indices.reduce(0) { $0 + sizes[$1] - minimum($1) }
        for index in indices where capacity > 0 {
            let available = sizes[index] - minimum(index)
            let taken = demand * available / capacity
            sizes[index] -= taken
            demand -= taken
            capacity -= available
        }
    }

    package mutating func rememberSize(at index: Int) {
        contract.panels[index]?.preferred = sizes[index]
    }

    private var spareCells: Int {
        contract.budget - sizes.reduce(0, +)
    }

    private func canUseSpare(at index: Int, edge: PanelResizeEdge) -> Bool {
        // Spare cells are trailing space. An interior edge can share that space when the stack
        // naturally leaves it unused, including after the drag has taken the last spare cell.
        edge.isEnd && (index == sizes.count - 1 || contract.baseline.reduce(0, +) < contract.budget)
    }

    private func adjustablePeers(of index: Int, edge: PanelResizeEdge) -> [Int] {
        let neighbors = edge.isEnd ? (index + 1) ..< sizes.endIndex : sizes.startIndex ..< index
        return neighbors.filter { if case .flexible = contract.policies[$0] { true } else { false } }
    }
}

extension LayoutPreference {
    var minimumCells: Int {
        switch self {
        case let .fixed(value), let .flexible(value, _, _): max(0, min(4096, value))
        default: 0
        }
    }

    var maximumCells: Int {
        switch self {
        case .fixed: minimumCells
        case let .fit(maximum): max(0, min(4096, maximum))
        case let .flexible(_, maximum, _): max(minimumCells, min(4096, maximum ?? 4096))
        default: 4096
        }
    }
}
