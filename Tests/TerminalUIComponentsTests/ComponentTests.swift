import TerminalUIComponents
import TerminalUILayoutEngine
@testable import TerminalUIRuntime
import Testing

@MainActor
private final class Probe {
    var calls: [String: Int] = [:]
    var bindings: [String: Binding<String>] = [:]
    var callbacks: [String: () -> Void] = [:]
    var submits: [String] = []
    var initializations = 0
    var diagnostics: [String] = []
    var actions: [UIAction] = []
    func initial() -> String {
        initializations += 1; return ""
    }
}

@TerminalComponent
private struct Editor: TerminalView {
    @State private var text: String
    let name: String
    let probe: Probe
    init(name: String, probe: Probe) {
        self.name = name; self.probe = probe
        _text = State(wrappedValue: probe.initial())
    }

    var body: Element {
        probe.calls[name, default: 0] += 1
        probe.bindings[name] = $text
        probe.callbacks[name] = { text = "from callback" }
        return TextEditor(id: "draft", text: $text).onSubmit {
            probe.submits.append(name + ":" + text)
            text = ""
        }
    }
}

@MainActor
private final class Fixture: TerminalApplication {
    let probe = Probe()
    var keys = ["a", "b"]
    var hidden: Set<String> = []
    var rootCalls = 0
    var prefix = ""
    var alternate = false
    func view() -> Element {
        rootCalls += 1
        return Column {
            ForEach(keys, id: \.self) { key in
                alternate ? Component(AlternateEditor(name: prefix + key, probe: probe), key: "editor") :
                    ComponentEditor(name: prefix + key, probe: probe).element(key: key, visible: !hidden.contains(key))
            }
        }
    }

    func handle(_ action: UIAction) {
        probe.actions.append(action)
    }
}

/// ForEach accepts either views or ordinary elements; this fixture also exercises nested boundaries.
@MainActor
private struct ComponentEditor {
    let name: String
    let probe: Probe
    func element(key _: String, visible: Bool) -> Element {
        Component(Editor(name: name, probe: probe), key: "editor").visible(visible)
    }
}

@MainActor
private final class ManualScheduler {
    var work: [@MainActor () -> Void] = []
    func schedule(_ work: @escaping @MainActor () -> Void) {
        self.work.append(work)
    }

    func run() {
        let pending = work; work = []; pending.forEach { $0() }
    }
}

@MainActor
struct ComponentTests {
    @Test func `private state compiles retains and initializes only once per mount`() throws {
        let probe = Probe()
        let app = ComponentApplication(root: Editor(name: "one", probe: probe), schedule: { _ in })
        _ = app.resolve()
        let binding = try #require(probe.bindings["one"])
        binding.wrappedValue = "retained"
        _ = app.resolve(invalidateRoot: true)
        #expect(probe.initializations == 1)
        #expect(probe.bindings["one"]?.wrappedValue == "retained")
        #expect(UIEngine().render(app.resolve(), width: 30, height: 2)[0].hasPrefix("retained"))
        app.unmount()
        binding.wrappedValue = "stale"
        _ = app.resolve()
        #expect(probe.initializations == 2)
        #expect(probe.bindings["one"]?.wrappedValue == "")
    }

    @Test func `keyed reorder hidden mount and removal keep correct generations`() throws {
        let fixture = Fixture()
        let app = ComponentApplication(legacy: fixture, schedule: { _ in }, diagnostic: { fixture.probe.diagnostics.append($0) })
        _ = app.resolve()
        let a = try #require(fixture.probe.bindings["a"])
        let b = try #require(fixture.probe.bindings["b"])
        let staleCallback = try #require(fixture.probe.callbacks["a"])
        a.wrappedValue = "A"; b.wrappedValue = "B"
        _ = app.resolve()
        let target = try #require(app.focusTarget(path: ["a", "editor"], id: "draft"))
        fixture.keys = ["new", "b", "a"]
        fixture.hidden = ["a"]
        _ = app.resolve(invalidateRoot: true)
        #expect(fixture.probe.bindings["a"]?.wrappedValue == "A")
        #expect(fixture.probe.bindings["b"]?.wrappedValue == "B")
        #expect(app.focusTarget(path: ["a", "editor"], id: "draft") == target)
        #expect(fixture.probe.initializations == 3)
        fixture.keys = ["new", "b"]
        _ = app.resolve(invalidateRoot: true)
        a.wrappedValue = "old generation"
        staleCallback()
        #expect(!app.hasPendingUpdates)
        fixture.keys.append("a")
        _ = app.resolve(invalidateRoot: true)
        #expect(fixture.probe.bindings["a"]?.wrappedValue == "")
        #expect(app.focusTarget(path: ["a", "editor"], id: "draft") != target)
        #expect(fixture.probe.diagnostics.count == 2)
    }

    @Test func `child only writes do not evaluate parent or sibling and callbacks refresh inputs`() throws {
        let fixture = Fixture()
        let app = ComponentApplication(legacy: fixture, schedule: { _ in })
        _ = app.resolve()
        fixture.probe.bindings["a"]?.wrappedValue = "only a"
        let updated = app.resolve()
        #expect(fixture.rootCalls == 1)
        #expect(fixture.probe.calls["a"] == 2)
        #expect(fixture.probe.calls["b"] == 1)
        let fresh = UIEngine().render(updated, width: 30, height: 6)
        #expect(fresh[0].hasPrefix("only a"))
        fixture.prefix = "fresh-"
        _ = app.resolve(invalidateRoot: true)
        #expect(fixture.probe.calls["fresh-a"] == 1)
        #expect(fixture.probe.bindings["fresh-a"]?.wrappedValue == "only a")
        let target = try #require(app.focusTarget(path: ["a", "editor"], id: "draft"))
        let engine = UIEngine()
        #expect(engine.focus(target.engineID, in: app.resolve()))
        try app.handle(#require(engine.handle(.enter, in: app.resolve())))
        #expect(fixture.probe.submits == ["fresh-a:only a"])
        #expect(fixture.probe.actions.isEmpty)
    }

    @Test func `root isolation scoped I ds and host input barriers`() throws {
        let fixture = Fixture()
        let app = ComponentApplication(legacy: fixture, schedule: { _ in })
        let other = ComponentApplication(root: Editor(name: "other", probe: fixture.probe), schedule: { _ in })
        let host = TerminalHost()
        _ = host.renderIfNeeded(app, size: .init(columns: 30, rows: 8))
        let target = try #require(app.focusTarget(path: ["a", "editor"], id: "draft"))
        #expect(host.focus(target, in: app))
        host.handleInput(.character("a"), source: app)
        host.handleInput(.character("b"), source: app)
        host.handleInput(.shiftEnter, source: app)
        host.handleInput(.paste("c\nd"), source: app)
        host.handleInput(.enter, source: app)
        #expect(fixture.probe.submits == ["a:ab\nc\nd"])
        #expect(fixture.probe.bindings["b"]?.wrappedValue == "")
        #expect(host.renderIfNeeded(app, size: .init(columns: 30, rows: 8)) != nil)
        _ = other.resolve()
        #expect(other.focusTarget(id: "draft") != target)
        #expect(fixture.probe.bindings["other"]?.wrappedValue == "")
        #expect(fixture.probe.actions.isEmpty)
    }

    @Test func `scheduling transactions no ops and errors coalesce`() throws {
        let scheduler = ManualScheduler()
        let probe = Probe()
        let app = ComponentApplication(root: Editor(name: "one", probe: probe), schedule: scheduler.schedule)
        var wakeups = 0
        app.connect(.init(requestUpdate: { wakeups += 1 }))
        _ = app.resolve()
        let binding = try #require(probe.bindings["one"])
        enum Failure: Error { case expected }
        #expect(throws: Failure.self) {
            try app.transaction {
                binding.wrappedValue = "a"
                binding.wrappedValue = "ab"
                #expect(binding.wrappedValue == "ab")
                #expect(scheduler.work.isEmpty)
                _ = app.resolve()
                #expect(probe.calls["one"] == 1)
                throw Failure.expected
            }
        }
        #expect(scheduler.work.count == 1)
        #expect(app.metrics.stateWrites == 2)
        scheduler.run()
        #expect(wakeups == 1)
        _ = app.resolve()
        #expect(probe.calls["one"] == 2)
        binding.wrappedValue = "ab"
        #expect(!app.hasPendingUpdates)
        #expect(scheduler.work.isEmpty)
        #expect(app.metrics.scheduledFlushes == 1)
    }

    @Test func `custom setter normalizes once and falls back only for unclaimed actions`() throws {
        let legacy = CustomBindingApplication()
        let app = ComponentApplication(legacy: legacy, schedule: { _ in })
        let root = app.resolve()
        let engine = UIEngine()
        try app.handle(#require(engine.handle(.character("x"), in: root)))
        #expect(legacy.setterCalls == 1)
        #expect(legacy.value == "X")
        #expect(legacy.actions.isEmpty)
        #expect(engine.render(app.resolve(), width: 20, height: 2)[0].hasPrefix("X"))
        app.handle(.activated("legacy"))
        #expect(legacy.actions == [.activated("legacy")])
        let constant = Binding<String>.constant("read only")
        constant.wrappedValue = "ignored"
        #expect(constant.wrappedValue == "read only")
        struct Model { var title: String }
        var model = Model(title: "before")
        let projected = Binding(get: { model }, set: { model = $0 }).title
        projected.wrappedValue = "after"
        #expect(model.title == "after")
    }
}

@MainActor
private final class CustomBindingApplication: TerminalApplication {
    var value = ""
    var setterCalls = 0
    var actions: [UIAction] = []
    func view() -> Element {
        TextField(id: "global", text: Binding(get: { self.value }, set: { self.setterCalls += 1; self.value = $0.uppercased() }))
    }

    func handle(_ action: UIAction) {
        actions.append(action)
    }
}

extension ComponentTests {
    @Test func `duplicate sibling keys are diagnosed`() async {
        await #expect(processExitsWith: .failure) {
            await MainActor.run {
                let fixture = Fixture()
                fixture.keys = ["a", "a"]
                _ = ComponentApplication(legacy: fixture, schedule: { _ in }).resolve()
            }
        }
    }

    @Test func `incremental frames match full resolution across edits reorder and resize`() {
        let incrementalFixture = Fixture()
        let referenceFixture = Fixture()
        let incremental = ComponentApplication(legacy: incrementalFixture, schedule: { _ in })
        let reference = ComponentApplication(legacy: referenceFixture, schedule: { _ in })
        let engine = UIEngine()
        let referenceEngine = UIEngine()
        _ = incremental.resolve(); _ = reference.resolve()
        for index in 0 ..< 24 {
            let text = ["界", "a\nb\nc", "a long wrapped line with emoji 🐈 and more text", ""][index % 4]
            let key = index.isMultiple(of: 2) ? "a" : "b"
            incrementalFixture.probe.bindings[key]?.wrappedValue = text
            referenceFixture.probe.bindings[key]?.wrappedValue = text
            if index.isMultiple(of: 5) {
                incrementalFixture.keys.reverse(); referenceFixture.keys.reverse()
                incremental.invalidate()
            }
            let width = [12, 25, 40][index % 3]
            let height = [4, 8][index % 2]
            #expect(engine.renderGrid(incremental.resolve(), width: width, height: height) ==
                referenceEngine.renderGrid(reference.resolve(invalidateRoot: true), width: width, height: height))
        }
    }
}

@TerminalComponent
private struct AlternateEditor: TerminalView {
    @State private var text = "replacement"
    let name: String
    let probe: Probe
    var body: Element {
        probe.bindings[name] = $text
        return TextField(id: "draft", text: $text)
    }
}

extension ComponentTests {
    @Test func `replacing component type starts new state even with the same key`() {
        let fixture = Fixture()
        let app = ComponentApplication(legacy: fixture, schedule: { _ in })
        _ = app.resolve()
        fixture.probe.bindings["a"]?.wrappedValue = "original"
        fixture.alternate = true
        _ = app.resolve(invalidateRoot: true)
        #expect(fixture.probe.bindings["a"]?.wrappedValue == "replacement")
        fixture.alternate = false
        _ = app.resolve(invalidateRoot: true)
        #expect(fixture.probe.bindings["a"]?.wrappedValue == "")
    }

    @Test func `report representative incremental work`() {
        let fixture = Fixture()
        fixture.keys = (0 ..< 200).map(String.init)
        let app = ComponentApplication(legacy: fixture, schedule: { _ in })
        let engine = UIEngine()
        _ = engine.render(app.resolve(), width: 80, height: 24)
        let initialBodies = app.metrics.bodyEvaluations
        let initialLayout = engine.metrics
        let clock = ContinuousClock()
        let start = clock.now
        for index in 0 ..< 40 {
            fixture.probe.bindings["0"]?.wrappedValue = "Edit \(index) with 界"
            _ = engine.render(app.resolve(), width: 80, height: 24)
        }
        #expect(app.metrics.bodyEvaluations - initialBodies == 40)
        #expect(fixture.rootCalls == 1)
        #expect(fixture.probe.calls["199"] == 1)
        print("Components (200 keyed editors, 40 edits, 80x24): \(start.duration(to: clock.now)); "
            + "bodies \(app.metrics.bodyEvaluations - initialBodies), "
            + "reconciliations \(engine.metrics.reconciliations - initialLayout.reconciliations), "
            + "measurements \(engine.metrics.measurements - initialLayout.measurements), "
            + "paints \(engine.metrics.paints - initialLayout.paints)")
    }
}
