/// A panel border that can be dragged along its parent stack’s axis.
public enum PanelResizeEdge: Equatable, Sendable {
    case leading, trailing, top, bottom

    package var vertical: Bool {
        self == .top || self == .bottom
    }

    package var isEnd: Bool {
        self == .trailing || self == .bottom
    }
}

package struct PanelResize: Equatable {
    package var id: String
    package let edge: PanelResizeEdge
    package let minimum: Int
    package let maximum: Int
    package let preferredSize: Int?

    package var stateKey: String {
        "panelResize:" + (edge.vertical ? "height:" : "width:") + id
    }

    init(id: String, edge: PanelResizeEdge, minimum: Int, maximum: Int?, preferredSize: Int?) {
        self.id = id
        self.edge = edge
        self.minimum = max(0, min(4096, minimum))
        self.maximum = max(self.minimum, min(4096, maximum ?? 4096))
        self.preferredSize = preferredSize
    }
}
