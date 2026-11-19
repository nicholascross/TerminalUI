import TerminalUICore
import TerminalUILayoutEngine

/// Routing describes its effect without reaching into renderer state.
package enum InteractionOutcome {
    case unchanged
    case viewport(String)
    case rebuild(UIAction?)
    case textSelection(copy: String?)
    case panelResize(LayoutNode, PanelResizeCommit?)

    package var event: UIEventResult {
        switch self {
        case .unchanged, .viewport, .textSelection, .panelResize: .repaint
        case let .rebuild(action): .rebuild(action: action)
        }
    }
}

package struct PanelResizeCommit {
    package let callback: @MainActor (Int) -> Void
    package let size: Int
}
