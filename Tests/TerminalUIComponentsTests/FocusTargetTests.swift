import TerminalUI
import Testing

private enum FocusDestination: Hashable {
    case first, editor, modal, missing
}

extension FocusDestination: MenuItemDefinition {
    var id: Self { self }
    var title: String {
        switch self {
        case .first: "First"
        case .editor: "Editor"
        case .modal: "Modal"
        case .missing: "Missing"
        }
    }
}

@MainActor
private final class FocusProbe {
    var showEditor = true
    var hidden = false
    var enabled = true
    var modal = false
    var identity = 1
    var target = FocusDestination.editor
    var observed: [FocusDestination?] = []
    var raw: [ScopedFocusTarget?] = []
    var submitted: [String] = []
    var suffix = "first"
    var customAction = false
    var unavailable = false
    var events: [String] = []
    var readerBodies = 0
    var rootBodies = 0
}

@TerminalComponent
private struct FocusEditor: TerminalView {
    @State private var text = ""
    let probe: FocusProbe
    var body: some TerminalView {
        TextField(id: "editor", text: $text)
            .focusTarget(probe.target)
            .onSubmit { probe.submitted.append(text) }
    }
}

private struct FocusScreen: TerminalView {
    let probe: FocusProbe
    var body: some TerminalView {
        let suffix = probe.suffix
        Column {
            Button("First", id: "first")
                .focusTarget(FocusDestination.first)
                .visible(!probe.hidden)
                .enabled(probe.enabled)
            if probe.showEditor { FocusEditor(probe: probe).id(probe.identity) }
            Button("Outside", id: "outside")
        }
        .overlay {
            if probe.modal {
                Dialog(id: "dialog", title: "Modal") {
                    Button("Inside", id: "inside").focusTarget(FocusDestination.modal)
                }
            }
        }
        .onFocusChange(of: FocusDestination.self) {
            probe.observed.append($0)
            if $0 == .editor { probe.submitted.append(suffix) }
        }
        .onFocusChange { probe.raw.append($0) }
    }
}

private struct ExtractedFocusButton: TerminalView {
    var body: some TerminalView { Button("Extracted", id: "button") }
}

@TerminalComponent
private struct FocusValueReader: TerminalView {
    @ApplicationContext private var application
    let probe: FocusProbe
    var body: some TerminalView {
        probe.readerBodies += 1
        return Text("Current: \(application.focusedValue(of: FocusDestination.self)?.title ?? "None")")
    }
}

private struct FocusReadRoot: TerminalView {
    let probe: FocusProbe
    var body: some TerminalView {
        probe.rootBodies += 1
        return Column {
            Button("First").focusTarget(FocusDestination.first)
            FocusEditor(probe: probe)
            Button("Outside")
            FocusValueReader(probe: probe)
        }
    }
}

@TerminalComponent
private struct DefaultFocusMenus: TerminalView {
    @State private var open = false
    let probe: FocusProbe

    private var bar: MenuBar {
        if probe.customAction {
            return MenuBar(id: "bar", items: [FocusDestination.first, .editor]) {
                probe.events.append("custom:\($0.title)")
            }
        }
        return MenuBar(id: "bar", items: [FocusDestination.first, .editor], unavailableReason: {
            probe.unavailable && $0 == .editor ? "Wait" : nil
        })
    }

    var body: some TerminalView {
        Column {
            bar.id("bar")
                .onActivate { probe.events.append("before1") }
                .onActivate { probe.events.append("before2") }
            Button("First", id: "first").focusTarget(FocusDestination.first)
            Button("Editor", id: "editor").focusTarget(FocusDestination.editor)
            Button("Open", id: "open")
                .onActivate { open = true }
                .keyboardShortcut(.controlP)
        }
        .overlay {
            if open {
                Menu(id: "menu", title: "Choices", items: [FocusDestination.first, .editor], initialSelection: .editor)
                    .onActivate {
                        probe.events.append("dismiss")
                        open = false
                    }
                    .onDismiss {
                        probe.events.append("escape")
                        open = false
                    }
            }
        }
        .onFocusChange(of: FocusDestination.self) {
            if let target = $0 { probe.events.append("focus:\(target.title)") }
        }
    }
}

@MainActor
struct FocusTargetTests {
    @Test func `context focuses typed controls and observers follow keyboard and unregistered focus`() throws {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: FocusScreen(probe: probe))
        _ = app.preview()
        #expect(probe.observed.last == .some(.first))
        let editor = try #require(app.context.focusTarget(FocusDestination.editor))
        #expect(app.context.focus(FocusDestination.editor))
        #expect(app.focusedTarget == editor)
        #expect(probe.observed.last == .some(.editor))
        #expect(probe.raw.last == editor)
        app.send(.tab)
        #expect(probe.observed.last == .some(nil))
        app.send(.tab)
        #expect(probe.observed.last == .some(.first))
        #expect(!app.context.focus(FocusDestination.missing))
        #expect(probe.observed.last == .some(.first))
    }

    @Test func `typed identity preserves concrete types including erased values`() throws {
        enum Other: Hashable { case first }
        let app = ApplicationHarness(root: Column {
            Button("Integer").focusTarget(1)
            Button("Unsigned").focusTarget(UInt(1))
            Button("String").focusTarget("1")
            Button("Enum").focusTarget(FocusDestination.first)
            Button("Other").focusTarget(Other.first)
        })
        var targets: [ScopedFocusTarget] = []
        for id: AnyHashable in [1, UInt(1), "1", FocusDestination.first, Other.first] {
            let target = try #require(app.context.focusTarget(id))
            #expect(!targets.contains(target))
            targets.append(target)
            #expect(app.context.focus(id))
            #expect(app.focusedTarget == target)
        }
    }

    @Test func `registrations follow extracted bodies and ignore structural view paths`() throws {
        let app = ApplicationHarness(root: Column {
            Panel("Outer") {
                ExtractedFocusButton()
                    .focusTarget(FocusDestination.first)
                    .id("leaf")
            }.id("outer")
        })
        let typed = try #require(app.context.focusTarget(FocusDestination.first))
        #expect(typed == app.context.focusTarget(path: ["outer", "leaf"], id: "button"))
        #expect(app.context.focus(FocusDestination.first))
    }

    @Test func `named scopes distinguish repeated targets and stale scopes cannot reconnect`() throws {
        struct Screen: TerminalView {
            let probe: FocusProbe
            var body: some TerminalView {
                Column {
                    ExtractedFocusButton().focusTarget(FocusDestination.first).scope("left").id(probe.identity)
                    ExtractedFocusButton().focusTarget(FocusDestination.first).scope("right")
                }
            }
        }
        let probe = FocusProbe()
        var diagnostics: [String] = []
        let app = ApplicationHarness(root: Screen(probe: probe), diagnostic: { diagnostics.append($0) })
        let left = try #require(app.context.scope("left"))
        let right = try #require(app.context.scope("right"))
        let old = try #require(app.context.focusTarget(FocusDestination.first, in: left))
        #expect(app.context.focusTarget(FocusDestination.first, in: right) != old)
        #expect(app.context.focusTarget(FocusDestination.first) == nil)
        #expect(diagnostics == ["Ambiguous focus target"])
        #expect(app.context.focus(FocusDestination.first, in: left))
        #expect(app.focusedTarget == old)
        #expect(app.context.focusedValue(of: FocusDestination.self, in: left) == .first)
        #expect(app.context.focusedValue(of: FocusDestination.self, in: right) == nil)
        probe.identity = 2
        app.invalidate()
        #expect(app.context.focusTarget(FocusDestination.first, in: left) == nil)
        #expect(!app.context.focus(FocusDestination.first, in: left))
        let replacement = try #require(app.context.scope("left"))
        #expect(replacement != left)
        #expect(app.context.focus(FocusDestination.first, in: replacement))
        #expect(app.focusedTarget != old)
        #expect(!app.context.focus(old))
    }

    @Test func `hidden disabled and modal blocked targets cannot receive focus`() {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: FocusScreen(probe: probe))
        _ = app.preview()
        probe.hidden = true
        app.invalidate()
        #expect(!app.context.focus(FocusDestination.first))
        probe.hidden = false
        probe.enabled = false
        app.invalidate()
        #expect(!app.context.focus(FocusDestination.first))
        #expect(app.context.focus(FocusDestination.editor))
        probe.modal = true
        app.invalidate()
        _ = app.preview()
        #expect(!app.context.focus(FocusDestination.editor))
        #expect(app.context.focus(FocusDestination.modal))
        #expect(probe.observed.last == .some(.modal))
        probe.modal = false
        app.invalidate()
        _ = app.preview()
        #expect(probe.observed.last == .some(.editor))
    }

    @Test func `changing target values refreshes registrations without resetting control state`() throws {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: FocusScreen(probe: probe))
        #expect(app.context.focus(FocusDestination.editor))
        let original = try #require(app.context.focusTarget(FocusDestination.editor))
        app.send(.paste("retained"))
        probe.target = .missing
        probe.suffix = "updated"
        app.invalidate()
        #expect(app.context.focusTarget(FocusDestination.editor) == nil)
        #expect(app.context.focusTarget(FocusDestination.missing) == original)
        #expect(probe.observed.last == .some(.missing))
        let observations = probe.observed
        app.invalidate()
        _ = app.preview()
        #expect(probe.observed == observations)
        #expect(app.context.focus(FocusDestination.first))
        #expect(app.context.focus(FocusDestination.missing))
        app.send(.enter)
        #expect(probe.submitted.last == "retained")
        probe.target = .editor
        app.invalidate()
        #expect(app.context.focus(FocusDestination.first))
        #expect(app.context.focus(FocusDestination.editor))
        #expect(probe.submitted.last == "updated")
    }

    @Test func `removed controls release registrations and replacement handles are fresh`() throws {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: FocusScreen(probe: probe))
        let original = try #require(app.context.focusTarget(FocusDestination.editor))
        probe.showEditor = false
        app.invalidate()
        #expect(app.context.focusTarget(FocusDestination.editor) == nil)
        #expect(!app.context.focus(original))
        probe.showEditor = true
        app.invalidate()
        let replacement = try #require(app.context.focusTarget(FocusDestination.editor))
        #expect(replacement != original)
        #expect(app.context.focus(FocusDestination.editor))
        app.unmount()
        #expect(!app.context.focus(replacement))
    }

    @Test func `typed observation is limited to the observed subtree`() {
        var left: [FocusDestination?] = []
        var right: [FocusDestination?] = []
        let app = ApplicationHarness(root: Row {
            ExtractedFocusButton().focusTarget(FocusDestination.first)
                .onFocusChange(of: FocusDestination.self) { left.append($0) }
            ExtractedFocusButton().focusTarget(FocusDestination.editor)
                .onFocusChange(of: FocusDestination.self) { right.append($0) }
        })
        #expect(app.context.focus(FocusDestination.first))
        #expect(left.last == .some(.first))
        #expect(right.last == .some(nil))
        #expect(app.context.focus(FocusDestination.editor))
        #expect(left.last == .some(nil))
        #expect(right.last == .some(.editor))
    }

    @Test func `primitive container observers exclude targets in sibling subtrees`() {
        var left: [FocusDestination?] = []
        var right: [FocusDestination?] = []
        let app = ApplicationHarness(root: Row {
            Column {
                Button("First").focusTarget(FocusDestination.first)
            }.onFocusChange(of: FocusDestination.self) { left.append($0) }
            Column {
                Button("Editor").focusTarget(FocusDestination.editor)
            }.onFocusChange(of: FocusDestination.self) { right.append($0) }
        })
        #expect(app.context.focus(FocusDestination.first))
        #expect(left.last == .some(.first))
        #expect(right.last == .some(nil))
        #expect(app.context.focus(FocusDestination.editor))
        #expect(left.last == .some(nil))
        #expect(right.last == .some(.editor))
    }

    @Test func `focus requested by an observer supersedes pending older notifications`() {
        var context: TerminalApplicationContext?
        var observed: [FocusDestination?] = []
        let app = ApplicationHarness(root: Column {
            Button("First").focusTarget(FocusDestination.first)
            Button("Editor").focusTarget(FocusDestination.editor)
        }
        .onFocusChange(of: FocusDestination.self) { observed.append($0) }
        .onFocusChange(of: FocusDestination.self) {
            if $0 == .first { context?.focus(FocusDestination.editor) }
        })
        context = app.context
        _ = app.preview()
        #expect(app.focusedTarget == app.context.focusTarget(FocusDestination.editor))
        #expect(observed.last == .some(.editor))
    }

    @Test func `default menu activation focuses registered values after surrounding observers`() {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: DefaultFocusMenus(probe: probe))
        _ = app.preview()
        app.send(.altCharacter("2"))
        #expect(app.focusedTarget == app.context.focusTarget(FocusDestination.editor))
        #expect(probe.events == ["before1", "before2", "focus:Editor"])
    }

    @Test func `explicit non focus activation replaces default focus and retains surrounding observers`() throws {
        let probe = FocusProbe()
        probe.customAction = true
        let app = ApplicationHarness(root: DefaultFocusMenus(probe: probe))
        _ = app.preview()
        let bar = try #require(app.context.focusTarget(path: ["bar"], id: "bar"))
        app.send(.altCharacter("2"))
        #expect(app.focusedTarget == bar)
        #expect(probe.events == ["before1", "before2", "custom:Editor"])
    }

    @Test func `modal activation dismisses before default focus and dismissal does not activate`() throws {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: DefaultFocusMenus(probe: probe))
        _ = app.preview()
        #expect(app.context.focus(FocusDestination.editor))
        app.send(.controlP)
        #expect(app.preview().joined().contains("Choices"))
        probe.events = []
        app.send(.enter)
        #expect(!app.preview().joined().contains("Choices"))
        #expect(app.focusedTarget == app.context.focusTarget(FocusDestination.editor))
        #expect(probe.events == ["dismiss", "focus:Editor"])
        app.send(.controlP)
        let back = try #require(app.context.focusTarget(id: "menu.back"))
        #expect(app.context.focus(back))
        probe.events = []
        app.send(.enter)
        _ = app.preview()
        #expect(probe.events == ["escape", "focus:Editor"])
    }

    @Test func `unavailable menu entries do not notify activation observers or focus targets`() {
        let probe = FocusProbe()
        probe.unavailable = true
        let app = ApplicationHarness(root: DefaultFocusMenus(probe: probe))
        _ = app.preview()
        app.send(.character("2"))
        app.send(.altCharacter("2"))
        app.send(.controlCharacter("2"))
        app.send(.right)
        app.send(.enter)
        #expect(probe.events.isEmpty)
    }

    @Test func `nonconforming hashable definitions support default focus`() {
        struct Existing: Identifiable, Hashable {
            let id: Int
            let name: String
        }
        let item = Existing(id: 1, name: "Existing")
        let app = ApplicationHarness(root: Column {
            MenuBar(id: "existing", items: [item], itemTitle: \.name)
            Button("Target").focusTarget(item)
        })
        _ = app.preview()
        app.send(.character("1"))
        #expect(app.focusedTarget == app.context.focusTarget(item))
    }

    @Test func `unhandled keys bubble through typed observation scopes`() {
        var handled = false
        let app = ApplicationHarness(root: ExtractedFocusButton()
            .focusTarget(FocusDestination.first)
            .onFocusChange(of: FocusDestination.self) { _ in }
            .onAction {
                guard case .unhandledKey(.controlC) = $0 else { return false }
                handled = true
                return true
            })
        _ = app.preview()
        app.send(.controlC)
        #expect(handled)
    }

    @Test func `context focus reads update subscribed views without a handler or model mirror`() {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: FocusReadRoot(probe: probe))
        #expect(app.preview().joined().contains("Current: First"))
        #expect(app.context.focusedValue(of: FocusDestination.self) == .first)
        #expect(probe.rootBodies == 1)
        let bodies = probe.readerBodies
        #expect(app.context.focus(FocusDestination.editor))
        #expect(app.preview().joined().contains("Current: Editor"))
        #expect(app.context.focusedValue(of: FocusDestination.self) == .editor)
        #expect(probe.readerBodies == bodies + 1)
        #expect(probe.rootBodies == 1)
        app.send(.tab)
        #expect(app.preview().joined().contains("Current: None"))
        #expect(app.context.focusedValue(of: FocusDestination.self) == nil)
    }

    @Test func `context focus reads reflect semantic changes on an unchanged control`() {
        let probe = FocusProbe()
        let app = ApplicationHarness(root: FocusReadRoot(probe: probe))
        _ = app.preview()
        #expect(app.context.focus(FocusDestination.editor))
        #expect(app.preview().joined().contains("Current: Editor"))
        probe.target = .missing
        app.invalidate()
        #expect(app.preview().joined().contains("Current: Missing"))
        #expect(app.context.focusedValue(of: FocusDestination.self) == .missing)
    }
}
