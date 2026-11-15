/// Per-engine work counts, independent of component body evaluation and terminal writes.
public struct RenderingMetrics: Equatable, Sendable {
    public package(set) var reconciliations = 0
    public package(set) var measurements = 0
    public package(set) var paints = 0
    public package(set) var frames = 0
    public init() {}
}

package final class RenderingStatistics {
    package var metrics = RenderingMetrics()
    package init() {}
}
