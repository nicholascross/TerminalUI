import TerminalUIEngine

/// Private PTY fixture for engine interactions that do not belong in the application examples.
@MainActor
final class EngineInteractionProbe: TerminalApplication {
    let host: TerminalHost
    let resizeProbe: Bool
    var field = "Click to place caret: 界 café"
    var editor = "Editable scratchpad\nPaste multiple lines here."
    var status = "Probe ready"
    var savedWidth: Int?

    init(host: TerminalHost, resizeProbe: Bool) {
        self.host = host
        self.resizeProbe = resizeProbe
    }

    func view() -> Element {
        if resizeProbe {
            return .column([
                .row(spacing: 1, [
                    .panel(title: "Files", content: .text("File list"))
                        .layoutSizing(height: .flexible())
                        .resizable(id: "files", edge: .trailing, minimum: 12, maximum: 30, preferredSize: 18) { self.savedWidth = $0 },
                    .panel(title: "Details", content: .paragraph("Fill the remaining cells"))
                        .layoutSizing(width: .flexible(minimum: 22), height: .flexible()),
                ]).height(.fill()),
                .statusBar("Saved width: \(savedWidth.map(String.init) ?? "pending")"),
            ])
        }
        return .column(
            spacing: 1,
            [
                .text("Engine interaction probe").role(.heading),
                .button("Change theme", id: "theme"),
                .scrollView(
                    id: "outer",
                    content: .column(
                        spacing: 1,
                        [
                            .textField(id: "field", value: field),
                            .textEditor(id: "editor", value: editor).height(.fixed(4)),
                            .textField(id: "disabled", value: "Disabled field").enabled(false),
                            .panel(
                                title: "Nested scrolling",
                                content: .scrollView(
                                    id: "nested",
                                    content:
                                        .column((0..<20).map { .text("Nested row \($0)") })
                                ).height(.fixed(4))),
                            .paragraph([
                                TextSpan("Ready", role: .success), TextSpan(" Modified", role: .warning),
                                TextSpan(" Conflict", role: .error),
                            ]),
                            .column((0..<30).map { .text("Outer row \($0)") }),
                        ])
                ).height(.fill()),
                .statusBar(status),
            ])
    }

    func handle(_ action: UIAction) {
        switch action {
        case .textChanged("field", let value): field = value
        case .textChanged("editor", let value): editor = value
        case .activated("theme"): host.theme = .light
        case .unhandledKey(.altCharacter("x")):
            Task {
                do {
                    try await host.runInTerminal("/dev/null/terminalui-missing-command")
                } catch TerminalCommandError.launchFailed {
                    status = "Launch failed"
                } catch {
                    status = "Unexpected command error"
                }
                host.invalidate()
            }
        case .unhandledKey(.controlC): host.stop()
        default: break
        }
    }
}

@main
struct Main {
    @MainActor static func main() async throws {
        let resizeProbe = CommandLine.arguments.contains("--resize-probe")
        let host = TerminalHost(configuration: .init(colorCapability: .trueColor, mouseEnabled: true, mouseDragEnabled: resizeProbe), theme: .nord())
        try await host.run(EngineInteractionProbe(host: host, resizeProbe: resizeProbe))
    }
}
