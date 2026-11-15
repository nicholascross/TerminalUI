/// Final geometry from a node's most recent paint, in terminal cells.
package struct MouseGeometry {
    package let bounds: MouseRect
    package let clip: MouseRect
    package let enabled: Bool
    package var rows: [(id: String, bounds: MouseRect)] = []
    package var horizontalOffset = 0
    package var verticalOffset = 0

    package init(bounds: MouseRect, clip: MouseRect, enabled: Bool) {
        self.bounds = bounds
        self.clip = clip
        self.enabled = enabled
    }
}
