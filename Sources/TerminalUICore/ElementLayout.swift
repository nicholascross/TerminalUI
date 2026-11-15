/// A size offered to a layout, in cells. A nil dimension asks for the ideal size.
public struct LayoutProposal: Hashable, Sendable {
    public let width: Int?
    public let height: Int?

    public init(width: Int? = nil, height: Int? = nil) {
        self.width = width.map { max(0, min(4096, $0)) }
        self.height = height.map { max(0, min(4096, $0)) }
    }
}

/// Sizing preferences used by negotiated containers; ordinary stacks retain their existing rules.
public enum LayoutPreference: Equatable, Sendable {
    case automatic
    case content
    case fixed(Int)
    case fit(maximum: Int)
    case flexible(minimum: Int = 0, maximum: Int? = nil, weight: Int = 1)
}

/// A child of a layout. Measurements are valid only during the current synchronous layout call.
public struct LayoutSubview {
    public let width: LayoutPreference
    public let height: LayoutPreference
    public let isSpacer: Bool
    private let measure: (LayoutProposal) -> WidgetSize

    public init(width: LayoutPreference, height: LayoutPreference, isSpacer: Bool = false,
                measure: @escaping (LayoutProposal) -> WidgetSize) {
        self.width = width
        self.height = height
        self.isSpacer = isSpacer
        self.measure = measure
    }

    public func sizeThatFits(_ proposal: LayoutProposal) -> WidgetSize { measure(proposal) }
}

/// Placement of a visible child by index, relative to the container's content origin.
public struct LayoutPlacement: Equatable, Sendable {
    public let index: Int
    public let x: Int
    public let y: Int
    public let size: WidgetSize

    public init(index: Int, x: Int, y: Int, size: WidgetSize) {
        self.index = index
        self.x = max(0, min(4096, x))
        self.y = max(0, min(4096, y))
        self.size = size
    }
}

/// A pure layout strategy for ordinary elements. The engine owns drawing and interaction.
/// Implementations must not retain subviews or change application state during measurement/placement.
public protocol ElementLayout {
    func sizing(subviews: [LayoutSubview]) -> (width: LayoutPreference, height: LayoutPreference)
    func sizeThatFits(_ proposal: LayoutProposal, subviews: [LayoutSubview]) -> WidgetSize
    func placeSubviews(in size: WidgetSize, subviews: [LayoutSubview]) -> [LayoutPlacement]
    func placeSubviews(in size: WidgetSize, subviews: [LayoutSubview], alignment: Alignment?) -> [LayoutPlacement]
}

public extension ElementLayout {
    func sizing(subviews: [LayoutSubview]) -> (width: LayoutPreference, height: LayoutPreference) { (.content, .content) }
    func placeSubviews(in size: WidgetSize, subviews: [LayoutSubview], alignment: Alignment?) -> [LayoutPlacement] {
        placeSubviews(in: size, subviews: subviews)
    }
}
