/// Integer-cell size negotiation shared by builder rows/columns and custom layout users.
public struct StackLayout: ElementLayout {
    public enum Axis: Sendable { case horizontal, vertical }
    public let axis: Axis
    public let spacing: Int
    public let alignment: Alignment

    public init(axis: Axis, spacing: Int = 0, alignment: Alignment = .leading) {
        self.axis = axis
        self.spacing = max(0, min(4096, spacing))
        self.alignment = alignment
    }

    public func sizing(subviews: [LayoutSubview]) -> (width: LayoutPreference, height: LayoutPreference) {
        // Expansion propagates through nested containers; compact-only stacks remain compact.
        (
            subviews.contains { isFlexible($0.width) && !($0.isSpacer && axis == .vertical) } ? .flexible() : .content,
            subviews.contains { isFlexible($0.height) && !($0.isSpacer && axis == .horizontal) } ? .flexible() : .content
        )
    }

    public func sizeThatFits(_ proposal: LayoutProposal, subviews: [LayoutSubview]) -> WidgetSize {
        plan(proposal, subviews: subviews).size
    }

    public func placeSubviews(in size: WidgetSize, subviews: [LayoutSubview]) -> [LayoutPlacement] {
        plan(LayoutProposal(width: size.width, height: size.height), subviews: subviews).placements
    }

    public func placeSubviews(in size: WidgetSize, subviews: [LayoutSubview], alignment: Alignment?) -> [LayoutPlacement] {
        StackLayout(axis: axis, spacing: spacing, alignment: alignment ?? self.alignment)
            .placeSubviews(in: size, subviews: subviews)
    }

    private func plan(_ proposal: LayoutProposal, subviews: [LayoutSubview]) -> (size: WidgetSize, placements: [LayoutPlacement]) {
        guard !subviews.isEmpty else { return (WidgetSize(width: 0, height: 0), []) }
        let vertical = axis == .vertical
        let offeredMain = vertical ? proposal.height : proposal.width
        let offeredCross = vertical ? proposal.width : proposal.height
        let policies = subviews.map { vertical ? $0.height : $0.width }
        let initial = subviews.map {
            $0.sizeThatFits(vertical ? LayoutProposal(width: offeredCross) : LayoutProposal(height: offeredCross))
        }
        let gap = min(spacing, offeredMain ?? 4096)
        let totalGap = min(offeredMain ?? 4096, gap * min(4096, subviews.count - 1))
        var sizes = initial.enumerated().map { index, size in
            preferred(vertical ? size.height : size.width, policy: policies[index], offered: offeredMain != nil)
        }
        if let offeredMain {
            let budget = max(0, offeredMain - totalGap)
            compress(&sizes, policies: policies, budget: budget)
            expand(&sizes, policies: policies, budget: budget)
        }

        // In a row, allocated widths affect wrapping and therefore the row's preferred height.
        let measured = subviews.enumerated().map { index, child in
            child.sizeThatFits(
                vertical
                    ? LayoutProposal(width: offeredCross, height: sizes[index])
                    : LayoutProposal(width: sizes[index], height: offeredCross))
        }
        let crossSizes = measured.enumerated().map { index, size in
            let ideal = vertical ? size.width : size.height
            let policy: LayoutPreference = subviews[index].isSpacer ? .content : (vertical ? subviews[index].width : subviews[index].height)
            let desired: Int
            if let offeredCross, isFlexible(policy) {
                desired = min(offeredCross, upperBound(policy))
            } else {
                desired = preferred(ideal, policy: policy, offered: false)
            }
            return min(desired, offeredCross ?? 4096)
        }
        let main = min(4096, sizes.reduce(totalGap, +))
        let cross = crossSizes.max() ?? 0
        let size = WidgetSize(width: vertical ? cross : main, height: vertical ? main : cross)
        let crossAvailable = offeredCross ?? cross
        var offset = 0
        let placements = subviews.indices.map { index in
            let free = max(0, crossAvailable - crossSizes[index])
            let crossOffset: Int
            switch alignment {
            case .leading: crossOffset = 0
            case .center: crossOffset = free / 2
            case .trailing: crossOffset = free
            }
            let placement = LayoutPlacement(
                index: index, x: vertical ? crossOffset : offset,
                y: vertical ? offset : crossOffset,
                size: WidgetSize(
                    width: vertical ? crossSizes[index] : sizes[index],
                    height: vertical ? sizes[index] : crossSizes[index]))
            offset = min(4096, offset + sizes[index] + gap)
            return placement
        }
        return (size, placements)
    }

    private func preferred(_ ideal: Int, policy: LayoutPreference, offered: Bool) -> Int {
        switch policy {
        case .automatic, .content: return ideal
        case .fixed(let value): return bounded(value)
        case .fit(let maximum): return min(ideal, bounded(maximum))
        case .flexible(let minimum, _, _):
            return min(upperBound(policy), max(bounded(minimum), offered ? 0 : ideal))
        }
    }

    private func compress(_ sizes: inout [Int], policies: [LayoutPreference], budget: Int) {
        var overflow = max(0, sizes.reduce(0, +) - budget)
        // Fixed dimensions are reserved first. Under impossible constraints every child can shrink.
        for fixed in [false, true] where overflow > 0 {
            let indices = sizes.indices.filter { index in
                if case .fixed = policies[index] { return fixed }
                return !fixed
            }
            var total = indices.reduce(0) { $0 + sizes[$1] }
            var available = max(0, total - overflow)
            for index in indices {
                let old = sizes[index]
                let next = total > 0 ? available * old / total : 0
                sizes[index] = next
                available -= next
                total -= old
                overflow -= old - next
            }
        }
    }

    private func expand(_ sizes: inout [Int], policies: [LayoutPreference], budget: Int) {
        var remaining = max(0, budget - sizes.reduce(0, +))
        var active = sizes.indices.filter { isFlexible(policies[$0]) && sizes[$0] < upperBound(policies[$0]) }
        while remaining > 0, !active.isEmpty {
            var weightLeft = active.reduce(0) { $0 + weight(policies[$1]) }
            for index in active {
                let weight = weight(policies[index])
                let share = remaining * weight / weightLeft
                let added = min(share, upperBound(policies[index]) - sizes[index])
                sizes[index] += added
                remaining -= added
                weightLeft -= weight
            }
            active.removeAll { sizes[$0] >= upperBound(policies[$0]) }
        }
    }

    private func bounded(_ value: Int) -> Int { max(0, min(4096, value)) }
    private func isFlexible(_ policy: LayoutPreference) -> Bool {
        if case .flexible = policy { return true }
        return false
    }
    private func upperBound(_ policy: LayoutPreference) -> Int {
        if case .flexible(let minimum, let maximum, _) = policy { return max(bounded(minimum), bounded(maximum ?? 4096)) }
        return 4096
    }
    private func weight(_ policy: LayoutPreference) -> Int {
        if case .flexible(_, _, let value) = policy { return max(1, min(4096, value)) }
        return 1
    }
}
