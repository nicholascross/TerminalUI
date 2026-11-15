import TerminalUI

@MainActor
private final class Probe { var bindings: [String: Binding<String>] = [:] }

@TerminalComponent
private struct ProbeEditor: TerminalView {
    @State private var text = ""
    @State private var submitted = 0
    let name: String
    let probe: Probe
    var body: some TerminalView {
        probe.bindings[name] = $text
        return Panel(name) {
            Column {
                TextEditor(id: "draft", text: $text).height(.fixed(2))
                    .onSubmit {
                        submitted = text.count
                        text = ""
                    }
                Text("Submitted \(submitted) characters")
            }
        }.height(.fixed(5))
    }
}

@TerminalComponent
private struct ProbeRoot: TerminalView {
    @ApplicationContext private var application
    let probe: Probe
    private func focus(_ key: String) {
        if let target = application.focusTarget(path: [key], id: "draft") { application.focus(target) }
    }
    private func stop() { application.stop() }
    var body: some TerminalView {
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
        let probe = Probe()
        let application = TerminalApp(root: ProbeRoot(probe: probe))
        if let target = application.context.focusTarget(path: ["first"], id: "draft") { application.context.focus(target) }
        let idleUpdate = Task { @MainActor in
            try await Task.sleep(for: .milliseconds(150))
            probe.bindings["First"]?.wrappedValue = "idle change"
        }
        defer { idleUpdate.cancel() }
        try await application.run()
    }
}
