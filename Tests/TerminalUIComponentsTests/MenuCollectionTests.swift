import TerminalUI
import Testing

private struct Choice: MenuItemDefinition, Equatable {
    let id: Int
    let title: String
    var menuShortcut: MenuShortcut = .automatic
}

@MainActor
private final class MenuProbe {
    var items = [Choice(id: 1, title: "Alpha"), Choice(id: 2, title: "Beta")]
    var calls: [String] = []
    var suffix = "first"
    var hidden = false
    var modal = false
}

private struct CollectionBar: TerminalView {
    let probe: MenuProbe
    var body: some TerminalView {
        let suffix = probe.suffix
        MenuBar(id: "bar", items: probe.items, activeItem: probe.items.first) { item in
            probe.calls.append("\(item.id)-\(item.title)-\(suffix)")
        }
    }
}

private struct CollectionMenu: TerminalView {
    let probe: MenuProbe
    var body: some TerminalView {
        Menu(id: "menu", title: "Choices", items: probe.items) { item in
            probe.calls.append(item.title)
        }
    }
}

private struct ShortcutButtons: TerminalView {
    let probe: MenuProbe
    var body: some TerminalView {
        let suffix = probe.suffix
        Column {
            Button("First")
                .keyboardShortcut(.controlP)
                .onActivate { probe.calls.append("first-" + suffix) }
                .visible(!probe.hidden)
            Button("Second")
                .onActivate { probe.calls.append("second-" + suffix) }
                .keyboardShortcut(.controlP)
            Button("Disabled")
                .onActivate { probe.calls.append("disabled") }
                .keyboardShortcut(.controlD)
                .enabled(false)
        }
        .overlay {
            if probe.modal {
                Dialog(id: "dialog", title: "Modal") {
                    Button("Inside")
                        .onActivate { probe.calls.append("inside") }
                        .keyboardShortcut(.controlD)
                }
            }
        }
    }
}

@MainActor
struct MenuCollectionTests {
    @Test func `typed highlight survives reorder while activation uses current values and captures`() {
        let probe = MenuProbe()
        let app = ApplicationHarness(root: CollectionBar(probe: probe))
        _ = app.preview()
        app.send(.right)
        probe.items = [Choice(id: 2, title: "Updated beta"), Choice(id: 1, title: "Alpha")]
        probe.suffix = "updated"
        app.invalidate()
        #expect(app.preview().joined().contains(">*1 Updated beta"))
        app.send(.enter)
        app.send(.altCharacter("2"))
        app.send(.controlCharacter("1"))
        #expect(probe.calls == ["2-Updated beta-updated", "1-Alpha-updated", "2-Updated beta-updated"])
    }

    @Test func `defaults number only the first nine items and none opts out`() {
        let probe = MenuProbe()
        probe.items = (1...10).map { Choice(id: $0, title: "Choice \($0)") }
        probe.items[1].menuShortcut = .none
        let app = ApplicationHarness(root: CollectionBar(probe: probe))
        let screen = app.preview(width: 160).joined()
        #expect(screen.contains("1 Choice 1"))
        #expect(screen.contains("9 Choice 9"))
        #expect(!screen.contains("2 Choice 2"))
        app.send(.altCharacter("2"))
        app.send(.altCharacter("0"))
        app.send(.controlCharacter("9"))
        #expect(probe.calls == ["9-Choice 9-first"])
        app.send(.end)
        app.send(.enter)
        #expect(probe.calls.last == "10-Choice 10-first")
    }

    @Test func `explicit and automatic shortcut collisions take the first in collection order`() {
        let probe = MenuProbe()
        probe.items[0].menuShortcut = .key("2")
        let app = ApplicationHarness(root: CollectionBar(probe: probe))
        _ = app.preview()
        app.send(.character("2"))
        app.send(.altCharacter("2"))
        app.send(.controlCharacter("2"))
        #expect(probe.calls == Array(repeating: "1-Alpha-first", count: 3))
        probe.items.reverse()
        app.invalidate()
        app.send(.altCharacter("1"))
        #expect(probe.calls.last == "2-Beta-first")
    }

    @Test func `modal shortcuts are local and filtering preserves original labels`() {
        let probe = MenuProbe()
        let app = ApplicationHarness(root: CollectionMenu(probe: probe))
        _ = app.preview()
        app.send(.altCharacter("1"))
        #expect(probe.calls.isEmpty)
        app.send(.character("2"))
        #expect(probe.calls == ["Beta"])
        app.send(.paste("Beta"))
        let screen = app.preview().joined()
        #expect(screen.contains("2 Beta"))
        #expect(!screen.contains("Alpha"))
        app.send(.character("1"))
        #expect(probe.calls == ["Beta"])
        #expect(app.preview().joined().contains("No matching items."))
    }

    @Test func `modal highlight survives collection reordering`() {
        let probe = MenuProbe()
        let app = ApplicationHarness(root: CollectionMenu(probe: probe))
        _ = app.preview()
        app.send(.down)
        app.send(.down)
        probe.items.reverse()
        app.invalidate()
        app.send(.enter)
        #expect(probe.calls == ["Beta"])
    }

    @Test func `default highlight retains the first item identity before any navigation`() {
        let probe = MenuProbe()
        let app = ApplicationHarness(root: CollectionMenu(probe: probe))
        _ = app.preview()
        probe.items.reverse()
        app.invalidate()
        app.send(.enter)
        #expect(probe.calls == ["Alpha"])
    }

    @Test func `empty typed collections render a usable empty menu`() {
        let probe = MenuProbe()
        probe.items = []
        let app = ApplicationHarness(root: CollectionMenu(probe: probe))
        #expect(app.preview().joined().contains("No matching items."))
        app.send(.enter)
        #expect(probe.calls.isEmpty)
    }

    @Test func `nonconforming values and colliding string descriptions retain typed identity`() {
        struct ID: Hashable, CustomStringConvertible {
            let value: Int
            var description: String { "same" }
        }
        struct Existing: Identifiable {
            let id: ID
            let name: String
        }
        let items = [Existing(id: ID(value: 1), name: "One"), Existing(id: ID(value: 2), name: "Two")]
        var calls: [Int] = []
        let app = ApplicationHarness(root: MenuBar(
            id: "existing", items: items, activeItem: items[1], itemTitle: \.name,
            shortcut: { $0.id.value == 1 ? .none : .key("p") }
        ) { item in calls.append(item.id.value) })
        #expect(app.preview().joined().contains("*P Two"))
        app.send(.enter)
        app.send(.controlP)
        app.send(.altCharacter("p"))
        #expect(calls == [2, 2, 2])
    }

    @Test func `menu specific title and shortcut closures override conformance`() {
        let items = [Choice(id: 1, title: "Alpha", menuShortcut: .none)]
        var calls: [Choice] = []
        let app = ApplicationHarness(root: Menu(
            id: "override", title: "Override", items: items,
            itemTitle: { "Focus \($0.title)" }, shortcut: { _ in .key("a") }
        ) { calls.append($0) })
        #expect(app.preview().joined().contains("a Focus Alpha"))
        app.send(.character("a"))
        #expect(calls == items)
    }

    @Test func `custom titles preserve shortcut preferences from conformance`() {
        var calls: [Int] = []
        let app = ApplicationHarness(root: MenuBar(
            id: "bar", items: [Choice(id: 1, title: "Alpha", menuShortcut: .key("a"))],
            itemTitle: { "Focus \($0.title)" }
        ) { calls.append($0.id) })
        #expect(app.preview().joined().contains("A Focus Alpha"))
        app.send(.altCharacter("1"))
        #expect(calls.isEmpty)
        app.send(.altCharacter("a"))
        #expect(calls == [1])
    }

    @Test func `button shortcuts refresh captures respect visibility and use first match`() {
        let probe = MenuProbe()
        let app = ApplicationHarness(root: ShortcutButtons(probe: probe))
        _ = app.preview()
        app.send(.controlP)
        probe.suffix = "updated"
        app.invalidate()
        app.send(.controlP)
        app.send(.controlD)
        probe.hidden = true
        app.invalidate()
        app.send(.controlP)
        #expect(probe.calls == ["first-first", "first-updated", "second-updated"])
    }

    @Test func `button shortcuts cannot escape a modal and return after it is removed`() {
        let probe = MenuProbe()
        let app = ApplicationHarness(root: ShortcutButtons(probe: probe))
        _ = app.preview()
        probe.modal = true
        app.invalidate()
        app.send(.controlP)
        app.send(.controlD)
        #expect(probe.calls == ["inside"])
        probe.modal = false
        app.invalidate()
        app.send(.controlP)
        #expect(probe.calls == ["inside", "first-first"])
    }
}
