import TerminalUIComponents
import Testing

@MainActor
private final class Dependencies {
    var first: Binding<String>?
    var second: Binding<String>?
    var useFirst: Binding<Bool>?
    var parentCalls = 0
    var childCalls = 0
}

@TerminalComponent
private struct SharedState: TerminalView {
    @State private var first = "first"
    @State private var second = "second"
    @State private var useFirst = true
    let probe: Dependencies
    var body: Element {
        probe.parentCalls += 1
        probe.first = $first; probe.second = $second; probe.useFirst = $useFirst
        return BindingReader(first: $first, second: $second, useFirst: $useFirst, probe: probe).bodyBoundary
    }
}

private struct BindingReader: TerminalView {
    @Binding var first: String
    @Binding var second: String
    @Binding var useFirst: Bool
    let probe: Dependencies
    var bodyBoundary: Element {
        Component(self)
    }

    var body: Element {
        probe.childCalls += 1
        return Text(useFirst ? first : second)
    }
}

@MainActor
struct DependencyTests {
    @Test func `binding reads subscribe the child and replace dynamic dependencies`() {
        let probe = Dependencies()
        let app = ComponentApplication(root: SharedState(probe: probe), schedule: { _ in })
        let engine = UIEngine()
        _ = app.resolve()
        probe.first?.wrappedValue = "changed"
        #expect(engine.render(app.resolve(), width: 20, height: 1)[0].hasPrefix("changed"))
        #expect(probe.parentCalls == 1)
        #expect(probe.childCalls == 2)
        probe.useFirst?.wrappedValue = false
        #expect(engine.render(app.resolve(), width: 20, height: 1)[0].hasPrefix("second"))
        probe.first?.wrappedValue = "no subscriber"
        #expect(!app.hasPendingUpdates)
        _ = app.resolve()
        #expect(probe.childCalls == 3)
        probe.second?.wrappedValue = "now subscribed"
        #expect(engine.render(app.resolve(), width: 20, height: 1)[0].hasPrefix("now subscribed"))
        #expect(probe.parentCalls == 1)
        #expect(probe.childCalls == 4)
    }
}
