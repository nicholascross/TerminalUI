@testable import TerminalUI
import TerminalUIEngine
import TerminalUIBridge
import Testing

@MainActor
private final class SelectionProbe {
    var list: Binding<String?>?
    var table: Binding<String>?
    var tabs: Binding<String?>?
}

@TerminalComponent
private struct Selections: TerminalView {
    @State private var list: String? = "a"
    @State private var table = "a"
    @State private var tabs: String? = "a"
    let probe: SelectionProbe
    var body: some TerminalView {
        probe.list = $list; probe.table = $table; probe.tabs = $tabs
        return Column {
            TerminalUI.List(id: "list", rows: [ListRow(id: "a", title: "Alpha"), ListRow(id: "b", title: "Beta")], selection: $list).height(.fixed(2))
            TerminalUI.Table(
                id: "table",
                columns: [TableColumn("Title")],
                rows: [TableRow(id: "a", cells: ["Alpha"]), TableRow(id: "b", cells: ["Beta"])],
                selection: $table,
            ).height(.fixed(3))
            TerminalUI.Tabs(id: "tabs", tabs: [Tab(id: "a", title: "Alpha"), Tab(id: "b", title: "Beta")], selection: $tabs)
        }
    }
}

@MainActor
struct SelectionTests {
    @Test func `list table and tabs use existing routers and typed bindings`() throws {
        let probe = SelectionProbe()
        let app = ComponentApplication(root: Selections(probe: probe), schedule: { _ in })
        let engine = UIEngine()
        for (id, key) in [("list", KeyEvent.down), ("table", .down), ("tabs", .right)] {
            let target = try #require(app.focusTarget(id: id))
            #expect(engine.focus(target.engineID, in: app.resolve()))
            try app.handle(#require(engine.handle(key, in: app.resolve())))
            _ = app.resolve()
        }
        #expect(probe.list?.wrappedValue == "b")
        #expect(probe.table?.wrappedValue == "b")
        #expect(probe.tabs?.wrappedValue == "b")
    }
}
