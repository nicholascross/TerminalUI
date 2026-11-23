import TerminalUI
import Testing

@MainActor
struct NotificationTests {
    @Test func `banner expiration removes its layout and leaves focus in place`() async throws {
        let app = ApplicationHarness(
            root: Column(spacing: 1) {
                Button("Workspace", id: "workspace")
                Banner("Saved", style: .success, timeout: .zero)
                Text("Footer")
            })
        #expect(app.preview()[2].contains("Success · Saved"))
        let focused = app.focusedTarget
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)
        while app.preview()[2].contains("Saved"), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(app.preview()[2].hasPrefix("Footer"))
        #expect(focused == app.focusedTarget)
    }

    @Test func `a replaced banner cancels its own timer and the new banner can offer an action`() async throws {
        let probe = NotificationProbe()
        var diagnostics: [String] = []
        let app = ApplicationHarness(root: ReplacedBanner(probe: probe), diagnostic: { diagnostics.append($0) })
        #expect(app.preview()[0].contains("Warning · Try again"))
        probe.replace = true
        app.invalidate()
        #expect(app.preview()[0].contains("Error · Try again"))
        try await Task.sleep(for: .milliseconds(30))
        #expect(app.preview()[0].contains("Error · Try again"))
        app.send(.enter)
        #expect(probe.retries == 1)
        #expect(diagnostics.isEmpty)
    }

    @Test func `acknowledgement is required and restores workspace focus`() {
        let probe = NotificationProbe()
        let app = ApplicationHarness(root: DialogExample(probe: probe, options: []))
        _ = app.preview()
        let workspaceFocus = app.focusedTarget
        app.send(.enter)
        let visible = app.preview(width: 40, height: 12)
        #expect(visible[0].contains("Open workspace"))
        #expect(visible.contains { $0.contains(">[OK]") })
        app.send(.escape)
        #expect(app.preview().contains { $0.contains("Notice") })
        app.send(.enter)
        #expect(probe.choices == [.acknowledge])
        #expect(!app.preview().contains { $0.contains("Notice") })
        #expect(app.focusedTarget == workspaceFocus)
    }

    @Test func `short dialogs reveal the preferred option and accept a different choice`() {
        let probe = NotificationProbe()
        let options = (1...15).map { DialogOption(id: String($0), title: "Option \($0)") }
        let app = ApplicationHarness(root: DialogExample(probe: probe, options: options, preferred: "12"))
        _ = app.preview(width: 24, height: 7)
        app.send(.enter)
        #expect(app.preview(width: 24, height: 7).contains { $0.contains(">[Option 12]") })
        app.send(.tab)
        #expect(app.preview(width: 24, height: 7).contains { $0.contains(">[Option 13]") })
        app.send(.enter)
        #expect(probe.choices == [options[12]])
    }

    @Test func `the dialog requests a refresh when an application owned binding closes`() {
        let probe = NotificationProbe()
        probe.replace = true
        let root = Text("Workspace").choiceDialog(
            id: "notice", title: "Notice", isPresented: Binding(get: { probe.replace }, set: { probe.replace = $0 }))
        let app = ApplicationHarness(root: root)
        #expect(app.preview().contains { $0.contains(">[OK]") })
        app.send(.enter)
        #expect(!probe.replace)
        #expect(!app.preview().contains { $0.contains("Notice") })
    }
}

@MainActor
private final class NotificationProbe {
    var replace = false
    var retries = 0
    var choices: [DialogOption] = []
}

private struct ReplacedBanner: TerminalView {
    let probe: NotificationProbe

    var body: some TerminalView {
        Banner(
            "Try again", style: probe.replace ? .error : .warning,
            timeout: probe.replace ? nil : .milliseconds(10), action: .init("Retry") { probe.retries += 1 })
    }
}

@TerminalComponent
private struct DialogExample: TerminalView {
    let probe: NotificationProbe
    let options: [DialogOption]
    var preferred: String? = nil
    @State private var open = false

    var body: some TerminalView {
        Button("Open workspace").onActivate { open = true }
            .choiceDialog(
                id: "notice", title: "Notice", message: "Review the changes before continuing. Follow these steps to review the details.",
                isPresented: $open, options: options, initialOption: preferred
            ) { probe.choices.append($0) }
    }
}
