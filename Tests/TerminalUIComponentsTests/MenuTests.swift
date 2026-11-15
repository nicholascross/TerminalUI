import TerminalUI
import Testing

private enum MenuMode: Sendable {
    case local, bound, values
}

@TerminalComponent
private struct MenuExample: TerminalView {
    @State private var isOpen = false
    @State private var query = ""
    @State private var selection: String? = "beta"
    @State private var chosen = "none"
    let mode: MenuMode
    let initialSelection: String?

    init(mode: MenuMode = .local, initialSelection: String? = "beta") {
        self.mode = mode
        self.initialSelection = initialSelection
    }

    private var items: [MenuItem] {
        [MenuItem(id: "alpha", title: "Alpha"), MenuItem(id: "beta", title: "Beta")]
    }

    private var menu: Menu {
        switch mode {
        case .local:
            Menu(id: "menu", title: "Choose an item", items: items, initialSelection: initialSelection)
        case .bound:
            Menu(id: "menu", title: "Choose an item", items: items, query: $query, selection: $selection)
        case .values:
            Menu(id: "menu", title: "Choose an item", items: items, query: query, selection: selection)
        }
    }

    var body: some TerminalView {
        Column {
            Button("Open", id: "open").onActivate { isOpen = true }
            Text("Chosen: \(chosen)")
            Text("Query: \(query)")
            Text("Selection: \(selection ?? "none")")
        }
        .overlay {
            if isOpen {
                menu.onDismiss { isOpen = false }
            }
        }
        .onAction { action in
            switch action {
            case .activated(let id) where id == "alpha" || id == "beta":
                chosen = id
                isOpen = false
            case .textChanged("menu.search", let value): query = value
            case .selectionChanged("menu.items", let value): selection = value
            default: return false
            }
            return true
        }
    }
}

@MainActor
struct DeclarativeMenuTests {
    private func screen(_ app: ApplicationHarness<MenuExample>) -> String {
        app.preview().joined(separator: "\n")
    }

    @Test func `local menu state survives refresh and resets after dismissal`() {
        let app = ApplicationHarness(root: MenuExample())
        #expect(screen(app).contains("Open"))
        app.send(.enter)
        app.send(.paste("Alpha"))
        #expect(!screen(app).contains("Beta"))
        app.invalidate()
        #expect(!screen(app).contains("Beta"))
        app.send(.escape)
        #expect(!screen(app).contains("Choose an item"))
        app.send(.enter)
        #expect(screen(app).contains("Beta"))
        app.send(.enter)
        #expect(screen(app).contains("Chosen: beta"))
    }

    @Test func `menu without an initial selection activates the first match`() {
        let app = ApplicationHarness(root: MenuExample(initialSelection: nil))
        _ = app.preview()
        app.send(.enter)
        app.send(.enter)
        #expect(screen(app).contains("Chosen: alpha"))
    }

    @Test(arguments: [MenuMode.bound, .values])
    private func `caller owned values and bindings retain their event behavior`(_ mode: MenuMode) {
        let app = ApplicationHarness(root: MenuExample(mode: mode))
        _ = app.preview()
        app.send(.enter)
        app.send(.down)
        app.send(.up)
        app.send(.escape)
        #expect(screen(app).contains("Selection: alpha"))
        app.send(.enter)
        app.send(.paste("Alpha"))
        app.send(.escape)
        #expect(screen(app).contains("Query: Alpha"))
        app.send(.enter)
        #expect(!screen(app).contains("Beta"))
        app.send(.enter)
        #expect(screen(app).contains("Chosen: alpha"))
    }

    @Test func `return button invokes the same dismissal callback as escape`() throws {
        let app = ApplicationHarness(root: MenuExample())
        _ = app.preview()
        app.send(.enter)
        let button = try #require(app.context.focusTarget(id: "menu.back"))
        #expect(app.context.focus(button))
        app.send(.enter)
        #expect(!screen(app).contains("Choose an item"))
        let opener = try #require(app.context.focusTarget(id: "open"))
        #expect(app.focusedTarget == opener)
    }
}
