import TerminalUI
import Testing

@MainActor
private final class CompositionProbe {
    var values: [String: Binding<String>] = [:]
    var callbacks: [String: () -> Void] = [:]
    var initializations: [String: Int] = [:]
    var bodies: [String: Int] = [:]
    var submitted: [String] = []
    var branch = false
    var optional = false
    var hidden = false
    var removed = false
    var identity = 1
    var leftScopeName = "left"
    var items = ["a", "b"]
    func initial(_ name: String) -> String {
        initializations[name, default: 0] += 1
        return name
    }
}

@TerminalComponent
private struct TypedEditor: TerminalView {
    @State private var text: String
    let name: String
    let probe: CompositionProbe
    init(_ name: String, probe: CompositionProbe) {
        self.name = name
        self.probe = probe
        _text = State(wrappedValue: probe.initial(name))
    }
    var body: some TerminalView {
        probe.bodies[name, default: 0] += 1
        probe.values[name] = $text
        probe.callbacks[name] = { text = "callback-" + name }
        return TextField(id: "editor", text: $text).onSubmit { probe.submitted.append(name + ":" + text) }
    }
}

private struct ConditionalScreen: TerminalView {
    let probe: CompositionProbe
    var body: some TerminalView {
        Column {
            if probe.optional { TypedEditor("optional", probe: probe) }
            TypedEditor("fixed", probe: probe)
            if probe.branch { TypedEditor("first", probe: probe).id("branch") } else { TypedEditor("second", probe: probe).id("branch") }
            if !probe.removed { TypedEditor("visible", probe: probe).visible(!probe.hidden) }
            TypedEditor("identity", probe: probe).id(probe.identity)
        }
    }
}

private struct CollectionsScreen: TerminalView {
    let probe: CompositionProbe
    var body: some TerminalView {
        Column {
            ForEach(probe.items, id: \.self) { TypedEditor("left-" + $0, probe: probe).id($0) }.scope(probe.leftScopeName)
            ForEach(probe.items, id: \.self) { TypedEditor("right-" + $0, probe: probe).id($0) }.scope("right")
        }
    }
}

@MainActor
private final class LoweringProbe {
    var first: Binding<String>?
    var second: Binding<String>?
    var selection: Binding<Bool>?
    var parents = 0
    var children = 0
}

@TerminalComponent
private struct LoweringOwner: TerminalView {
    @State private var first = "first"
    @State private var second = "second"
    @State private var selection = true
    let probe: LoweringProbe
    var body: some TerminalView {
        probe.parents += 1
        probe.first = $first
        probe.second = $second
        probe.selection = $selection
        return LoweringReader(first: $first, second: $second, selection: $selection, probe: probe)
    }
}

private struct LoweringReader: TerminalView {
    let first: Binding<String>
    let second: Binding<String>
    let selection: Binding<Bool>
    let probe: LoweringProbe
    var body: some TerminalView {
        probe.children += 1
        // All three reads happen during primitive lowering, after this body returns.
        return TextField(
            id: "read",
            text: Binding(
                get: {
                    selection.wrappedValue ? first.wrappedValue : second.wrappedValue
                },
                set: { value in
                    if selection.wrappedValue { first.wrappedValue = value } else { second.wrappedValue = value }
                }))
    }
}

@MainActor
struct TypedCompositionTests {
    @Test func `primitive lowering records reads under the child and replaces subscriptions`() throws {
        let probe = LoweringProbe()
        let app = ApplicationHarness(root: LoweringOwner(probe: probe))
        #expect(app.preview()[0].hasPrefix("first"))
        probe.first?.wrappedValue = "changed"
        #expect(app.preview()[0].hasPrefix("changed"))
        #expect(probe.parents == 1)
        #expect(probe.children == 2)
        probe.selection?.wrappedValue = false
        #expect(app.preview()[0].hasPrefix("second"))
        probe.first?.wrappedValue = "unsubscribed"
        #expect(!app.hasPendingUpdates)
        probe.second?.wrappedValue = "subscribed"
        #expect(app.preview()[0].hasPrefix("subscribed"))
        #expect(probe.parents == 1)
        #expect(probe.children == 4)
    }

    @Test func `branch slots optional slots visibility and explicit identity have distinct lifetimes`() throws {
        let probe = CompositionProbe()
        let app = ApplicationHarness(root: ConditionalScreen(probe: probe))
        _ = app.preview()
        probe.values["fixed"]?.wrappedValue = "retained"
        probe.values["second"]?.wrappedValue = "branch state"
        let staleIdentity = try #require(probe.values["identity"])
        let staleCallback = try #require(probe.callbacks["identity"])
        probe.optional = true
        probe.branch = true
        probe.hidden = true
        probe.identity = 2
        app.invalidate()
        _ = app.preview()
        #expect(probe.values["fixed"]?.wrappedValue == "retained")
        #expect(probe.initializations["visible"] == 1)
        #expect(probe.initializations["identity"] == 2)
        staleIdentity.wrappedValue = "stale"
        staleCallback()
        #expect(probe.values["identity"]?.wrappedValue == "identity")
        #expect(!app.hasPendingUpdates)
        probe.branch = false
        probe.optional = false
        probe.removed = true
        app.invalidate()
        _ = app.preview()
        #expect(probe.values["second"]?.wrappedValue == "second")
        probe.optional = true
        probe.removed = false
        app.invalidate()
        _ = app.preview()
        #expect(probe.initializations["optional"] == 2)
        #expect(probe.initializations["visible"] == 2)
        #expect(probe.initializations["fixed"] == 1)
    }

    @Test func `independent keyed collections preserve state on reorder and support scoped addresses`() throws {
        let probe = CompositionProbe()
        var diagnostics: [String] = []
        let app = ApplicationHarness(root: CollectionsScreen(probe: probe), diagnostic: { diagnostics.append($0) })
        _ = app.preview()
        let left = try #require(app.context.scope("left"))
        let right = try #require(app.context.scope("right"))
        let target = try #require(app.context.focusTarget(path: ["a"], id: "editor", in: left))
        #expect(app.context.focusTarget(path: ["a"], id: "editor", in: right) != target)
        #expect(app.context.focusTarget(path: ["a"], id: "editor") == nil)
        #expect(!app.context.reveal("a"))
        #expect(diagnostics.count == 2)
        #expect(app.context.reveal("a", in: left))
        probe.values["left-a"]?.wrappedValue = "left retained"
        probe.values["right-a"]?.wrappedValue = "right retained"
        probe.items.reverse()
        app.invalidate()
        _ = app.preview()
        #expect(app.context.focusTarget(path: ["a"], id: "editor", in: left) == target)
        #expect(probe.values["left-a"]?.wrappedValue == "left retained")
        #expect(probe.values["right-a"]?.wrappedValue == "right retained")
        #expect(probe.initializations["left-a"] == 1)
        #expect(app.context.focus(target))
        app.send(.enter)
        #expect(probe.submitted == ["left-a:left retained"])
        app.unmount()
        _ = app.preview()
        #expect(app.context.focusTarget(path: ["a"], id: "editor", in: left) == nil)
        #expect(!app.context.reveal("a", in: left))
        #expect(!app.context.focus(target))
    }

    @Test func `reveal uses typed equality and rejects absent hidden and ambiguous targets`() {
        let app = ApplicationHarness(
            root: Column {
                Text("integer").id(1)
                Text("unsigned").id(UInt(1))
                Text("string").id("1")
                Text("hidden").id("hidden").visible(false)
                Text("duplicate one").id("duplicate")
                Text("duplicate two").id("duplicate")
            })
        _ = app.preview()
        #expect(app.context.reveal(1))
        #expect(app.context.reveal(UInt(1)))
        #expect(app.context.reveal("1"))
        #expect(!app.context.reveal("hidden"))
        #expect(!app.context.reveal("missing"))
        #expect(!app.context.reveal("duplicate"))
    }

    @Test func `nested scroll reveal makes the current target visible without resetting state`() throws {
        let probe = CompositionProbe()
        let app = ApplicationHarness(
            root: ScrollView(id: "outer") {
                Column {
                    for index in 0..<12 { Text("line \(index)") }
                    ScrollView(id: "inner") {
                        Column {
                            for index in 0..<12 { Text("inside \(index)") }
                            TypedEditor("target", probe: probe).id("target")
                        }
                    }.height(.fixed(3))
                }
            }.height(.fixed(5)))
        _ = app.preview(width: 30, height: 5)
        probe.values["target"]?.wrappedValue = "revealed value"
        #expect(app.context.reveal("target"))
        #expect(app.preview(width: 30, height: 5).joined().contains("revealed value"))
        #expect(probe.initializations["target"] == 1)
    }
}

private struct ExtractedButton: TerminalView {
    var body: some TerminalView { Button("Extracted", id: "button") }
}

extension TypedCompositionTests {
    @Test func `event modifiers on extracted views resolve through deferred component bodies`() {
        var activated = 0
        var actions = 0
        var focusChanges = 0
        let app = ApplicationHarness(
            root: ExtractedButton()
                .onActivate { activated += 1 }
                .onAction { _ in
                    actions += 1
                    return true
                }
                .onFocusChange { _ in focusChanges += 1 })
        _ = app.preview()
        app.send(.enter)
        #expect(activated == 1)
        app.send(.controlC)
        #expect(actions == 1)
        #expect(focusChanges > 0)
    }
}

extension TypedCompositionTests {
    @Test func `scope renaming and style changes preserve mounts while unmount releases every generation`() throws {
        let probe = CompositionProbe()
        let app = ApplicationHarness(root: CollectionsScreen(probe: probe))
        _ = app.preview()
        let scope = try #require(app.context.scope("left"))
        let target = app.context.focusTarget(path: ["a"], id: "editor", in: scope)
        let mounted = app.metrics.mounts
        probe.leftScopeName = "renamed"
        app.invalidate()
        _ = app.preview()
        #expect(app.context.scope("left") == nil)
        #expect(app.context.scope("renamed") == scope)
        #expect(app.context.focusTarget(path: ["a"], id: "editor", in: scope) == target)
        #expect(app.metrics.mounts == mounted)
        #expect(app.metrics.unmounts == 0)
        app.unmount()
        #expect(app.metrics.mounts == app.metrics.unmounts)
    }

    @Test func `named key and submission actions reach the owning extracted component`() {
        struct LocalActions: TerminalView {
            let action: @MainActor (UIAction) -> Bool
            var body: some TerminalView {
                TextField(id: "field", value: "")
                    .onKey(.controlP, activate: "shortcut")
                    .onSubmit("submit")
                    .onAction(action)
            }
        }
        var received: [UIAction] = []
        let app = ApplicationHarness(
            root: Column {
                LocalActions(action: {
                    received.append($0)
                    return true
                })
            })
        _ = app.preview()
        app.send(.controlP)
        app.send(.enter)
        #expect(received == [.activated("shortcut"), .activated("submit")])
    }
}
