/// A stack child's preferred size along an axis.
public enum LayoutSize: Equatable, Sendable {
    case content
    /// Use capped content size after reserving space for fixed and ordinary content siblings.
    case fit(maximum: Int)
    case fixed(Int)
    case fill(weight: Int = 1)
}
