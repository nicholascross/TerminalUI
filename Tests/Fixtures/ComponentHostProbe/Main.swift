import TerminalUIComponents

@MainActor
private final class Probe { var bindings: [String: Binding<String>] = [:] }

@TerminalComponent
private struct ProbeEditor: TerminalView {
    @State private var text = ""
    @State private var submitted = 0
    let name: String
    let probe: Probe
    var body: Element {
        probe.bindings[name] = $text
        return Panel(name) {
            Column {
                TextEditor(id: "draft", text: $text).height(.fixed(2))
                    .onSubmit { submitted = text.count; text = "" }
                Text("Submitted \(submitted) characters")
            }
        }.height(.fixed(5))
    }
}

private struct ProbeRoot: TerminalView {
    let probe: Probe
    let focus: (String) -> Void
    let stop: () -> Void
    var body: Element {
        Column {
            Text("Component idle probe")
            Component(ProbeEditor(name: "First", probe: probe), key: "first")
            Component(ProbeEditor(name: "Second", probe: probe), key: "second")
        }.onAction { action in
            switch action {
            case .unhandledKey(.altCharacter("1")): focus("first")
            case .unhandledKey(.altCharacter("2")): focus("second")
            case .unhandledKey(.controlC): stop()
            default: return false
            }
            return true
        }
    }
}

@main
struct ComponentHostProbe {
    @MainActor static func main() async throws {
        let host = TerminalHost()
        let probe = Probe()
        var application: ComponentApplication!
        application = ComponentApplication(root: ProbeRoot(probe: probe, focus: { key in
            if let target = application.focusTarget(key: key, id: "draft") { host.focus(target, in: application) }
        }, stop: { host.stop() }))
        _ = application.resolve()
        if let target = application.focusTarget(key: "first", id: "draft") { host.focus(target, in: application) }
        let idleUpdate = Task { @MainActor in
            try await Task.sleep(for: .milliseconds(150))
            probe.bindings["First"]?.wrappedValue = "idle change"
        }
        defer { idleUpdate.cancel(); application.unmount() }
        try await host.run(application)
    }
}
