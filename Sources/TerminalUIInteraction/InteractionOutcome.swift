import TerminalUICore

/// Routing describes its effect without reaching into renderer state.
package enum InteractionOutcome {
    case unchanged
    case viewport(String)
    case rebuild(UIAction?)
    case textSelection(copy: String?)

    package var event: UIEventResult {
        switch self {
        case .unchanged, .viewport, .textSelection: .repaint
        case let .rebuild(action): .rebuild(action: action)
        }
    }
}
