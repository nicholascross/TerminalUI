import TerminalUIComponents

/// Bridges typed demo destinations to the host's opaque, generation-scoped focus handles.
@MainActor
struct LayoutNavigation {
    let application: TerminalApplicationContext

    func target(for pane: Pane) -> ScopedFocusTarget? {
        application.focusTarget(path: ["workspace", pane], id: pane.rawValue)
    }

    func pane(for target: ScopedFocusTarget?) -> Pane? {
        guard let target else { return nil }
        return Pane.allCases.first { self.target(for: $0) == target }
    }

    @discardableResult
    func focus(_ pane: Pane) -> Bool {
        guard let target = target(for: pane) else { return false }
        return application.focus(target)
    }

    func stop() {
        application.stop()
    }
}
