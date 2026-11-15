import TerminalUI
import Testing

@testable import RepositoryDemoSupport

@MainActor
struct RepositoryNavigationTests {
    private func screen(_ app: ApplicationHarness<RepositoryScreen>) -> String {
        app.preview(width: 80, height: 32).joined(separator: "\n")
    }

    @Test func browserSharesRepositoryChangesAndRetainsLocalPresentationState() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        try fixture.write("first.txt", "first\n")
        try fixture.write("second.txt", "second\n")
        var model = try RepositoryViewModel(repository: GitRepository(directory: fixture.url.path))
        let app = ApplicationHarness(root: RepositoryBrowser(model: Binding(
            get: { model }, set: { model = $0 })))
        _ = app.preview(width: 120, height: 40)

        app.send(.down)
        #expect(model.file == "second.txt")
        app.send(.backTab)
        app.send(.paste("second"))

        try fixture.write("second-new.txt", "new\n")
        model.refresh()
        app.invalidate()
        let refreshed = app.preview(width: 120, height: 40).joined(separator: "\n")
        #expect(refreshed.contains("?? second.txt"))
        #expect(refreshed.contains("?? second-new.txt"))
        #expect(!refreshed.contains("?? first.txt"))
        #expect(model.snapshot.files.contains { $0.path == "first.txt" })

        app.send(.controlP)
        #expect(app.preview(width: 120, height: 40).joined(separator: "\n").contains("Repository commands"))

        model.selectFile("first.txt")
        app.invalidate()
        #expect(app.preview(width: 120, height: 40).joined(separator: "\n").contains("Repository commands"))
        app.send(.escape)
        let output = app.preview(width: 120, height: 40).joined(separator: "\n")
        #expect(!output.contains("Repository commands"))
        #expect(output.contains("?? second.txt"))
        #expect(!output.contains("?? first.txt"))
        #expect(output.contains("Working diff · first.txt"))
    }

    @Test func workspaceAdaptsToPreviewDimensionsAndPreservesFiltering() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        try fixture.write("first.txt", "first\n")
        try fixture.write("second.txt", "second\n")
        let app = ApplicationHarness(root: RepositoryScreen(directory: fixture.url.path))
        let wide = app.preview(width: 120, height: 40)
        #expect(wide.contains { $0.contains("Files ·") && $0.contains("Inspect ·") })
        app.send(.backTab)
        app.send(.paste("second"))
        let filterTarget = try #require(app.focusedTarget)
        let fileTarget = try #require(app.context.focusTarget(RepositoryPane.files))
        let narrow = app.preview(width: 80, height: 32)
        #expect(app.focusedTarget == filterTarget)
        #expect(app.context.focusTarget(RepositoryPane.files) == fileTarget)
        #expect(!narrow.contains { $0.contains("Files ·") && $0.contains("Inspect ·") })
        #expect(narrow.joined(separator: "\n").contains("?? second.txt"))
        #expect(!narrow.joined(separator: "\n").contains("?? first.txt"))
        let expanded = app.preview(width: 120, height: 40)
        #expect(app.focusedTarget == filterTarget)
        #expect(app.context.focusTarget(RepositoryPane.files) == fileTarget)
        #expect(expanded.contains { $0.contains("Files ·") && $0.contains("Inspect ·") })
        #expect(expanded.joined(separator: "\n").contains("?? second.txt"))
        #expect(!expanded.joined(separator: "\n").contains("?? first.txt"))
    }

    @Test func screenLoadsWhenMountedAndRetriesRepositoryFailures() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        // Constructing a screen does not query Git. The repository can appear before mounting.
        let root = RepositoryScreen(directory: fixture.url.path)
        try fixture.git(["init", "-b", "main"])
        let app = ApplicationHarness(root: root)
        #expect(screen(app).contains("READ ONLY"))
        #expect(!screen(app).contains("Repository unavailable"))

        let missing = fixture.url.appendingPathComponent("later")
        let retryApp = ApplicationHarness(root: RepositoryScreen(directory: missing.path))
        #expect(screen(retryApp).contains("Repository unavailable"))
        #expect(screen(retryApp).contains("Retry"))
        try fixture.git(["init", "-b", "main", missing.path])
        retryApp.send(.enter)
        #expect(screen(retryApp).contains("READ ONLY"))
        #expect(!screen(retryApp).contains("Repository unavailable"))
        #expect(retryApp.focusedTarget == retryApp.context.focusTarget(RepositoryPane.files))
    }

    @Test func shortcutsAndCommandsPreserveFilteringAndScopeFocus() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        try fixture.write("first.txt", "first\n")
        try fixture.write("second.txt", "second\n")
        let app = ApplicationHarness(root: RepositoryScreen(directory: fixture.url.path))
        #expect(screen(app).contains("READ ONLY"))
        #expect(app.focusedTarget == app.context.focusTarget(RepositoryPane.files))
        // The filter is immediately before the initially focused file list.
        app.send(.backTab)
        app.send(.paste("second"))
        #expect(screen(app).contains("?? second.txt"))
        #expect(!screen(app).contains("?? first.txt"))
        for (index, pane) in RepositoryPane.allCases.enumerated() {
            let key = Character(String(index + 1))
            for shortcut in [KeyEvent.altCharacter(key), .controlCharacter(key)] {
                app.send(shortcut)
                #expect(app.focusedTarget == app.context.focusTarget(pane))
            }
        }
        app.send(.controlP)
        #expect(screen(app).contains("Repository commands"))
        #expect(!app.context.focus(RepositoryPane.files))
        app.send(.altCharacter("1"))
        #expect(screen(app).contains("Repository commands"))
        app.send(.escape)
        #expect(!screen(app).contains("Repository commands"))
        #expect(app.focusedTarget == app.context.focusTarget(RepositoryPane.inspector))
        app.send(.controlP)
        app.send(.paste("Refresh repository"))
        app.send(.enter)
        #expect(screen(app).contains("Repository refreshed"))
        #expect(screen(app).contains("?? second.txt"))
        #expect(!screen(app).contains("?? first.txt"))
        // Reopening discards the previous search. Help is available through the same menu.
        app.send(.controlP)
        app.send(.paste("Repository help"))
        app.send(.enter)
        #expect(screen(app).contains("Read-only Git browser"))
        app.send(.escape)
        #expect(!screen(app).contains("Read-only Git browser"))
    }

    @Test func refreshingPreservesStagedAndBranchInspectionsAndReportsErrors() throws {
        let fixture = try RepositoryFixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        try fixture.git(["config", "user.name", "Demo Test"])
        try fixture.git(["config", "user.email", "demo@example.test"])
        try fixture.write("file.txt", "original\n")
        try fixture.git(["add", "."])
        try fixture.git(["commit", "-m", "Initial commit"])
        try fixture.git(["branch", "feature"])
        try fixture.write("file.txt", "staged\n")
        try fixture.git(["add", "."])
        try fixture.write("file.txt", "working\n")
        var model = try RepositoryViewModel(repository: GitRepository(directory: fixture.url.path))
        model.showStagedDiff()
        model.refresh()
        #expect(model.inspection == .staged)
        #expect(model.output.contains("+staged"))
        #expect(!model.output.contains("+working"))
        model.selectBranch("feature")
        model.refresh()
        #expect(model.inspection == .branch)
        #expect(model.branch == "feature")
        #expect(model.output.contains("Initial commit"))
        let previous = model.output
        model.selectBranch("missing")
        #expect(model.status.hasPrefix("Git error:"))
        #expect(model.output == previous)
    }
}
