import TerminalUIEngine

/// Private PTY fixture for engine interactions that do not belong in the application examples.
@MainActor
final class EngineInteractionProbe: TerminalApplication {
    let host: TerminalHost
    var field = "Click to place caret: 界 café"
    var editor = "Editable scratchpad\nPaste multiple lines here."

    init(host: TerminalHost) { self.host = host }

    func view() -> Element {
        .column(
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
                .statusBar("Probe ready"),
            ])
    }

    func handle(_ action: UIAction) {
        switch action {
        case .textChanged("field", let value): field = value
        case .textChanged("editor", let value): editor = value
        case .activated("theme"): host.theme = .light
        case .unhandledKey(.controlC): host.stop()
        default: break
        }
    }
}

@main
struct Main {
    @MainActor static func main() async throws {
        let host = TerminalHost(configuration: .init(colorCapability: .trueColor, mouseEnabled: true), theme: .nord())
        try await host.run(EngineInteractionProbe(host: host))
    }
}
