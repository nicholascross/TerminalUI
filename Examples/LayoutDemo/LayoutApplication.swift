import TerminalUIComponents

/// Owns terminal services; shared UI state and commands belong to LayoutViewModel.
@MainActor
public final class LayoutApplication {
    public let host: TerminalHost
    public lazy var presentation = ComponentApplication(root: LayoutScreen(
        currentPane: { [weak self] in self?.currentPane },
        navigate: { [weak self] control in self?.focus(control) },
        quit: { [weak self] in self?.host.stop() },
    ))

    public init(mouseEnabled: Bool = true) {
        host = TerminalHost(configuration: TerminalConfiguration(mouseEnabled: mouseEnabled), theme: .dusk())
    }

    private var currentPane: String? {
        switch host.focusedID?.split(separator: ":").last {
        case "topics": "pane.topics"
        case "inspector": "pane.inspector"
        case "command": "pane.command"
        default: nil
        }
    }

    func target(_ control: String) -> ScopedFocusTarget? {
        presentation.focusTarget(path: ["workspace", control], id: control)
    }

    private func focus(_ control: String) {
        if let target = target(control) { host.focus(target, in: presentation) }
    }
}
