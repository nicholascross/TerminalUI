import TerminalUI
import Testing

@MainActor
private final class UsabilityProbe {
    var calls: [String] = []
    var suffix = "first"
    var items = ["a", "b"]
    var hidden = false
}

private struct AnonymousButtons: TerminalView {
    let probe: UsabilityProbe
    var body: some TerminalView {
        let suffix = probe.suffix
        return Column {
            Button("First").onActivate { probe.calls.append("first-" + suffix) }
            Button("Second").onActivate { probe.calls.append("second-" + suffix) }
            ForEach(probe.items, id: \.self) { item in
                Button(item).onActivate { probe.calls.append(item + "-" + suffix) }
            }
        }
    }
}

private struct UsabilityChoice: MenuItemDefinition {
    let id: String
    let title: String
    var menuShortcut: MenuShortcut = .automatic
    var unavailableReason: String? = nil
}

private struct ActionBars: TerminalView {
    let probe: UsabilityProbe
    var body: some TerminalView {
        let suffix = probe.suffix
        return Column {
            MenuBar(id: "left", items: [
                UsabilityChoice(id: "same", title: "Left"),
                UsabilityChoice(id: "unavailable", title: "Unavailable", menuShortcut: .key("3"), unavailableReason: "Try later"),
            ], unavailableReason: \.unavailableReason) { item in
                probe.calls.append(item.title.lowercased() + "-" + suffix)
            }.visible(!probe.hidden)
            MenuBar(id: "right", items: [
                UsabilityChoice(id: "same", title: "Right", menuShortcut: .key("2")),
            ]) { item in
                probe.calls.append(item.title.lowercased() + "-" + suffix)
            }
        }
    }
}

@TerminalComponent
private struct ActionPopup: TerminalView {
    @State private var open = false
    let probe: UsabilityProbe

    private func choose(_ value: String) {
        probe.calls.append(value)
        open = false
    }

    var body: some TerminalView {
        Column {
            Button("Open").onActivate { open = true }
            MenuBar(id: "background", items: [
                UsabilityChoice(id: "background", title: "Background", menuShortcut: .key("9")),
            ]) { item in probe.calls.append(item.id) }
        }
        .overlay {
            if open {
                Menu(id: "popup", title: "Pick an action", items: [
                    UsabilityChoice(id: "alpha", title: "Alpha"),
                    // Item IDs are independent of the menu's internal control IDs.
                    UsabilityChoice(id: "popup.back", title: "Beta"),
                    UsabilityChoice(id: "unavailable", title: "Unavailable", unavailableReason: "Try later"),
                ], unavailableReason: \.unavailableReason) { item in
                    choose(item.title.lowercased())
                }
                .onDismiss { open = false }
            }
        }
    }
}

@TerminalComponent
private struct FocusPreferences: TerminalView {
    @State private var open = false

    var body: some TerminalView {
        Column {
            Button("Disabled", id: "disabled").initialFocus().enabled(false)
            Button("Hidden", id: "hidden").initialFocus().visible(false)
            Button("First", id: "first")
            Button("Preferred", id: "preferred").initialFocus()
            Button("Open", id: "open").onActivate { open = true }
        }
        .overlay {
            if open {
                Dialog(id: "dialog", title: "Focus") {
                    Button("Other", id: "other")
                    Button("Preferred modal", id: "modal").initialFocus()
                }
                .onDismiss { open = false }
            }
        }
    }
}

private struct LocalCollections: TerminalView {
    let probe: UsabilityProbe
    var body: some TerminalView {
        Column {
            if !probe.hidden {
                List(id: "list", rows: [ListRow(id: "a", title: "Alpha"), ListRow(id: "b", title: "Beta")])
                    .height(.fixed(3))
                Table(id: "table", columns: [TableColumn("Title")],
                      rows: [TableRow(id: "a", cells: ["Alpha"]), TableRow(id: "b", cells: ["Beta"])])
                    .height(.fixed(4))
            }
        }
    }
}

@MainActor
struct UsabilityTests {
    @Test func `anonymous sibling buttons keep distinct identities and refresh callbacks`() throws {
        let probe = UsabilityProbe()
        let app = ApplicationHarness(root: AnonymousButtons(probe: probe))
        _ = app.preview()
        app.send(.enter)
        app.send(.tab)
        app.send(.enter)
        app.send(.tab)
        let target = try #require(app.focusedTarget)
        probe.items.reverse()
        probe.suffix = "updated"
        app.invalidate()
        _ = app.preview()
        #expect(app.focusedTarget == target)
        app.send(.enter)
        #expect(probe.calls == ["first-first", "second-first", "a-updated"])
    }

    @Test func `callback menu bars isolate IDs shortcuts and current callback captures`() throws {
        let probe = UsabilityProbe()
        let app = ApplicationHarness(root: ActionBars(probe: probe))
        _ = app.preview()
        let right = try #require(app.context.focusTarget(id: "right"))
        #expect(app.context.focus(right))
        app.send(.enter)
        probe.suffix = "updated"
        app.invalidate()
        app.send(.altCharacter("1"))
        app.send(.altCharacter("2"))
        app.send(.altCharacter("3"))
        probe.hidden = true
        app.invalidate()
        app.send(.altCharacter("1"))
        #expect(probe.calls == ["right-first", "left-updated", "right-updated"])
    }

    @Test func `callback menus filter scope shortcuts and consume unavailable shortcuts`() {
        let probe = UsabilityProbe()
        let app = ApplicationHarness(root: ActionPopup(probe: probe))
        _ = app.preview()
        app.send(.enter)
        app.send(.character("3"))
        app.send(.altCharacter("9"))
        #expect(probe.calls.isEmpty)
        #expect(app.preview().joined().contains("Pick an action"))
        app.send(.paste("Beta"))
        app.send(.altCharacter("1"))
        #expect(probe.calls.isEmpty)
        app.send(.altCharacter("2"))
        #expect(probe.calls.isEmpty)
        app.send(.enter)
        #expect(probe.calls == ["beta"])
        app.send(.enter)
        app.send(.character("1"))
        #expect(probe.calls == ["beta", "alpha"])
    }

    @Test func `pointer activation invokes a menu row callback`() throws {
        let probe = UsabilityProbe()
        let app = ApplicationHarness(root: ActionPopup(probe: probe), configuration: .init(mouseEnabled: true))
        _ = app.preview()
        app.send(.enter)
        let lines = app.preview()
        let row = try #require(lines.firstIndex(where: { $0.contains("2 Beta") }))
        let column = try #require(lines[row].range(of: "2 Beta")).lowerBound
        let offset = lines[row].distance(from: lines[row].startIndex, to: column)
        app.send(.mouse(.init(.press, column: offset, row: row)))
        app.send(.mouse(.init(.release, column: offset, row: row)))
        #expect(probe.calls == ["beta"])
    }

    @Test func `initial focus skips unavailable controls preserves user choice and restores after modals`() throws {
        let app = ApplicationHarness(root: FocusPreferences())
        _ = app.preview()
        #expect(app.focusedTarget == app.context.focusTarget(id: "preferred"))
        let first = try #require(app.context.focusTarget(id: "first"))
        #expect(app.context.focus(first))
        app.invalidate()
        _ = app.preview()
        #expect(app.focusedTarget == first)
        let opener = try #require(app.context.focusTarget(id: "open"))
        #expect(app.context.focus(opener))
        app.send(.enter)
        _ = app.preview()
        #expect(app.focusedTarget == app.context.focusTarget(id: "modal"))
        app.send(.escape)
        _ = app.preview()
        #expect(app.focusedTarget == opener)
        app.unmount()
        _ = app.preview()
        #expect(app.focusedTarget == app.context.focusTarget(id: "preferred"))
    }

    @Test func `local list and table selection survives refresh and resets after removal`() throws {
        let probe = UsabilityProbe()
        let app = ApplicationHarness(root: LocalCollections(probe: probe))
        for id in ["list", "table"] {
            _ = app.preview()
            let target = try #require(app.context.focusTarget(id: id))
            #expect(app.context.focus(target))
            app.send(.down)
            app.invalidate()
            #expect(app.preview().joined().contains("> Beta"))
        }
        probe.hidden = true
        app.invalidate()
        _ = app.preview()
        probe.hidden = false
        app.invalidate()
        for id in ["list", "table"] {
            let target = try #require(app.context.focusTarget(id: id))
            #expect(app.context.focus(target))
            #expect(app.preview().joined().contains("> Alpha"))
        }
    }
}
