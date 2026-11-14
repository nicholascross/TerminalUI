import Foundation
import TerminalUI
import TerminalUIChroma

/// A read-only repository browser with accessible theme and component examples.
@MainActor
final class RepositoryApp: TerminalApplication {
    let host: TerminalHost
    let highlighter = SyntaxHighlighter()
    var columns = 100
    var rows = 30
    let repository: GitRepository
    var snapshot: GitRepository.Snapshot
    var inspection = "Select a changed file or commit."
    var inspectionTitle = "Working tree"
    var file = ""
    var branch = "main"
    var branchSelection = "main"
    var commit: String?
    var commitInspection = "No commits yet in this repository."
    var detail = "diff"
    var filter = ""
    var status = "Ready · read-only repository"
    var modal: String?
    var menuQuery = ""
    var menuSelection: String? = "theme"
    var themeIndex = 0
    let colorCapability: ColorCapability
    var themeNames: [String] { ["Dusk", "Dark", "Light", "Terminal native"] }
    var syntax = SyntaxExample.swift
    var sampleField = "Click to place caret: 界 café"
    var sampleEditor = "Editable scratchpad\nPaste multiple lines here."
    var sampleSelection: String? = "one"
    var barFocus: String? = "commands"
    var paths: [String] { snapshot.files.map(\.path) }
    var commits: [TableRow] {
        snapshot.commits.map { TableRow(id: $0.hash, cells: [String($0.hash.prefix(7)), $0.subject]) }
    }

    init(host: TerminalHost, repository: GitRepository, colorCapability: ColorCapability = .detect()) throws {
        self.colorCapability = colorCapability
        self.host = host
        self.repository = repository
        self.snapshot = try repository.snapshot()
        branch = snapshot.branch
        branchSelection = branch
        file = paths.first ?? ""
        commit = snapshot.commits.first?.hash
        if paths.isEmpty, commit != nil { try inspectCommit() }
        else { try inspectFile() }
    }

    var commands: [MenuItem] {
        [MenuItem(id: "refresh", title: "Refresh repository"),
         MenuItem(id: "diff.worktree", title: "View working tree diff"),
         MenuItem(id: "diff.staged", title: "View staged diff"),
         MenuItem(id: "inspect.commit", title: "View selected commit",
                  unavailableReason: commit == nil ? "No commits yet in this repository" : nil),
         MenuItem(id: "theme", title: "Switch theme"),
         MenuItem(id: "samples", title: "Theme and component samples"),
         MenuItem(id: "help", title: "Repository help")]
    }

    var navigationItems: [MenuItem] {
        zip("1234", ["Files", "Branches", "Commits", "Inspect"]).map { number, title in
            MenuItem(id: "pane.\(number)", title: title, shortcut: number,
                     globalShortcuts: [.altCharacter(number), .controlCharacter(number)])
        } + [MenuItem(id: "commands", title: "Commands", globalShortcuts: [.controlP]), MenuItem(id: "theme", title: "Theme"),
             MenuItem(id: "samples", title: "Samples"), MenuItem(id: "help", title: "Help")]
    }

    func view() -> Element {
        let sidebar = Element.column([
            surfacePanel("1 Files · \(paths.count) changed", content: .column([
                .textField(id: "filter", value: filter, placeholder: "Filter files").background(host.theme.field.background),
                .list(id: "files", rows: snapshot.files.compactMap { entry in
                    guard filter.isEmpty || entry.path.localizedCaseInsensitiveContains(filter) else { return nil }
                    return ListRow(id: entry.path, title: "\(entry.status) \(entry.path)")
                }, selection: file).onSubmit("diff.worktree").height(.fill())
            ])).height(.fill(weight: 2)),
            surfacePanel("2 Branches", content: .list(id: "branches", rows:
                snapshot.branches.map { ListRow(id: $0, title: ($0 == branch ? "* " : "  ") + $0) },
                selection: branchSelection).onSubmit("inspect.branch")).height(.fixed(5)),
            surfacePanel("3 Commits", content: snapshot.commits.isEmpty
                ? .text("No commits yet").role(.muted)
                : .table(id: "commits", columns: [
                TableColumn("Hash", width: .fixed(7)), TableColumn("Subject", width: .fill())
            ], rows: commits, selection: commit).onSubmit("inspect.commit")).height(.fill(weight: 2))
        ])
        let details = surfacePanel("4 Inspect · \(detail == "commit" ? "Commit · " + (commit.map { String($0.prefix(7)) } ?? "none") : inspectionTitle)", content: .column([
            .tabs(id: "detail", tabs: [Tab(id: "diff", title: "Git output"), Tab(id: "source", title: "Syntax"),
                                      Tab(id: "widgets", title: "Components"), Tab(id: "commit", title: "Commit")], selection: detail),
            detailContent.height(.fill())
        ]))
        let content: Element = columns < 85
            ? .column([sidebar.height(.fixed(max(10, rows / 2))), details.height(.fill())])
            : .row(spacing: 1, [sidebar.width(.fill(weight: 2)), details.width(.fill(weight: 3))])
        return .column([
            .row(spacing: 2, [
                .text("TerminalUI").role(.heading),
                .text("REPOSITORY").role(.accent).width(.fill()),
                .text(" READ ONLY ").role(.info).background(host.theme.info.background)
            ]),
            .paragraph([TextSpan("\(branch)", role: .accent),
                        TextSpan(" · \(paths.count) changed files · \(snapshot.commits.count) commits", role: .secondary)])
                .visible(rows >= 24),
            .menuBar(id: "toolbar", items: navigationItems,
                selection: nil, focusedItem: barFocus).padding(.init(bottom: rows >= 24 ? 1 : 0)),
            content.height(.fill()),
            .row(spacing: 1, [.button("Refresh", id: "refresh"),
                .button("Working diff", id: "diff.worktree"), .button("Staged diff", id: "diff.staged"),
                .button("Quit", id: "quit")]),
            .row(spacing: 1, [.statusBar(status).width(.fill()),
                .text(themeNames[themeIndex]).role(.accent)]),
            .keyHints("Alt+1–4: panes · Tab: focus · Enter: activate · wheel: scroll · Ctrl-P: commands · Ctrl-C: quit")
        ]).background(host.theme.normal.background).overlay(overlay)
    }

    private func surfacePanel(_ title: String, content: Element) -> Element {
        .panel(title: title, content: content.padding(.init(leading: 1, trailing: 1)))
            .background(host.theme.surface.background)
    }

    var detailContent: Element {
        switch detail {
        case "commit":
            let index = snapshot.commits.firstIndex { $0.hash == commit } ?? 0
            return .column([
                .row(spacing: 1, [
                    .button("Newer", id: "commit.newer").enabled(commit != nil && index > 0),
                    .button("Older", id: "commit.older").enabled(commit != nil && index + 1 < snapshot.commits.count)
                ]),
                gitOutput(commitInspection, id: "commit.output").height(.fill())
            ])
        case "source":
            return .column([
                .tabs(id: "syntax", tabs: SyntaxExample.allCases.map { Tab(id: $0.rawValue, title: $0.title) }, selection: syntax.rawValue),
                .scrollView(id: "source", content: .paragraph((try? highlighter.spans(syntax.source, language: syntax.rawValue)) ?? [TextSpan(syntax.source)])).height(.fill())
            ])
        case "widgets":
            return .scrollView(id: "components", content: .column(spacing: 1, [
                .text("Semantic styles").role(.heading),
                .paragraph([TextSpan(" Ready ", role: .success), TextSpan(" Modified ", role: .warning),
                            TextSpan(" Conflict ", role: .error), TextSpan(" Info ", role: .info, style: .init(background: host.theme.info.background)),
                            TextSpan(" Highlight ", role: .highlighted, style: .init(background: host.theme.highlighted.background))]),
                .text("Fields and editing").role(.secondary),
                .textField(id: "sample.field", value: sampleField).background(host.theme.field.background),
                .textEditor(id: "sample.editor", value: sampleEditor).background(host.theme.field.background).height(.fixed(4)),
                .textField(id: "sample.disabled", value: "Disabled field").enabled(false),
                .panel(title: "Nested scrolling", content: .scrollView(id: "nested", content:
                    .column((0..<20).map { .text("Nested row \($0)") })).height(.fixed(4))),
                .list(id: "sample.list", rows: [ListRow(id: "one", title: "Available"),
                    ListRow(id: "two", title: "Unavailable", isEnabled: false)], selection: sampleSelection).height(.fixed(2)),
                .progress(0.65),
                .row(spacing: 2, [.text("Bold").bold(), .text("Underline").underline(),
                                  .text("Dim").dim(), .text("Italic").italic()]),
                .row(spacing: 1, [
                    .text(" Surface ").background(host.theme.surface.background),
                    .text(" Field ").background(host.theme.field.background),
                    .text(" Selection ").style(.init(foreground: host.theme.selection.foreground,
                                                       background: host.theme.selection.background))
                ]),
                .text("RGB sample").foreground(.rgb(100, 180, 240)),
                .paragraph("Wheel over the inner pane, then continue at its boundary to scroll this outer view. Click a panel border to focus its controls."),
                .button("Repository help", id: "help")
            ]))
        default:
            return gitOutput(inspection, id: "diff")
        }
    }

    private func gitOutput(_ output: String, id: String) -> Element {
        .scrollView(id: id, content: .column(output.components(separatedBy: "\n").map { line in
            .text(line).role(line.hasPrefix("+") ? .success : line.hasPrefix("-") ? .error : line.hasPrefix("@@") ? .info : .normal)
        }))
    }

    var overlay: Element? {
        switch modal {
        case "commands":
            return .menu(id: "commands", title: "Repository commands", items: commands, query: menuQuery,
                         selection: menuSelection).width(.fixed(min(58, columns))).height(.fixed(min(13, rows)))
        case "help":
            return .dialog(id: "help", title: "Read-only Git browser", content: .column(spacing: 1, [
                .paragraph("Files shows git status (index and working tree columns). Select a file to inspect its working diff; use Staged diff for the index. Untracked files are listed without a diff. Refresh reloads external changes."),
                .paragraph("Select branches to inspect their recent history. Click a commit or press Enter in Commits to open its full message, author, date, changed files and patch. The Commit tab reopens the selected commit; Newer and Older step through history. Branch selection does not check out a branch. This browser only runs read-only Git queries."),
                .paragraph("Theme cycles Dusk, dark, light and terminal-native palettes. Samples opens the component gallery; Syntax shows highlighting examples. Click controls or use Alt+1–4, Tab and Enter. Wheel scrolls the pane under the pointer. Escape closes dialogs."),
                .button("Close", id: "close")
            ])).width(.fixed(min(68, columns)))
        default: return nil
        }
    }

    func handle(_ action: UIAction) {
        switch action {
        case .activated(let id) where id.hasPrefix("pane."):
            if let number = id.last { focusPane(number) }
        case .resized(let size): columns = size.columns; rows = size.rows
        case .selectionChanged("files", let id):
            file = id
            perform { try inspectFile(); status = "Selected \(id)" }
        case .selectionChanged("branches", let id):
            branchSelection = id
            perform {
                inspection = try repository.show(branch: id)
                inspectionTitle = "Branch · \(id)"; showOutput()
                status = "Inspecting branch \(id)"
            }
        case .selectionChanged("commits", let id):
            commit = id
            perform { try inspectCommit() }
        case .selectionChanged("detail", let id):
            detail = id
            if id == "commit" { perform { try inspectCommit() } }
            else { status = "View: \(id)" }
        case .selectionChanged("syntax", let id): syntax = SyntaxExample(rawValue: id) ?? .swift
        case .selectionChanged("sample.list", let id): sampleSelection = id
        case .selectionChanged("toolbar", let id): barFocus = id
        case .selectionChanged("commands.items", let id): menuSelection = id
        case .textChanged("filter", let value): filter = value
        case .textChanged("commands.search", let value): menuQuery = value
        case .textChanged("sample.field", let value): sampleField = value
        case .textChanged("sample.editor", let value): sampleEditor = value
        case .activated("inspect.branch"): handle(.selectionChanged("branches", branchSelection))
        case .activated("inspect.commit"):
            modal = nil
            perform { try inspectCommit() }
        case .activated("commit.newer"): moveCommit(by: -1)
        case .activated("commit.older"): moveCommit(by: 1)
        case .activated("refresh"):
            modal = nil
            perform {
                snapshot = try repository.snapshot()
                branch = snapshot.branch
                if !paths.contains(file) { file = paths.first ?? "" }
                if !snapshot.branches.contains(branchSelection) { branchSelection = branch }
                if !snapshot.commits.contains(where: { $0.hash == commit }) { commit = snapshot.commits.first?.hash }
                if detail == "commit" { try inspectCommit() }
                else { try inspectFile() }
                status = "Repository refreshed · read only"
            }
        case .activated("diff.worktree"): modal = nil; perform { try inspectFile() }
        case .activated("diff.staged"): modal = nil; perform { try inspectFile(staged: true) }
        case .activated("samples"): detail = "widgets"; modal = nil; status = "Theme and component samples"
        case .activated("commands"):
            modal = "commands"; menuQuery = ""; menuSelection = "theme"
        case .activated("theme"):
            themeIndex = (themeIndex + 1) % themeNames.count
            host.theme = [Theme.dusk(colorCapability: colorCapability), .dark, .light, .terminalNative][themeIndex]
            modal = nil; status = "Theme: \(themeNames[themeIndex])"
        case .activated("help"): modal = "help"
        case .activated("close"), .activated("commands.back"), .dismissRequested: modal = nil
        case .activated("quit"), .unhandledKey(.controlC): host.stop()
        case .pasteTruncated: status = "Paste truncated at configured byte limit"
        default: break
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation() }
        catch { status = "Git error: \(error.localizedDescription)" }
    }

    private func showOutput() {
        detail = "diff"
        host.resetState(for: "diff")
    }

    private func inspectCommit() throws {
        let output = try commit.map { try repository.show(commit: $0) }
        commitInspection = output ?? "No commits yet in this repository."
        detail = "commit"
        host.resetState(for: "commit.output")
        status = commit.map { "Selected commit \($0.prefix(7))" } ?? "No commits yet"
    }

    private func moveCommit(by offset: Int) {
        guard let index = snapshot.commits.firstIndex(where: { $0.hash == commit }),
              snapshot.commits.indices.contains(index + offset) else { return }
        commit = snapshot.commits[index + offset].hash
        perform { try inspectCommit() }
    }

    private func inspectFile(staged: Bool = false) throws {
        if let entry = snapshot.files.first(where: { $0.path == file }) {
            let output = try repository.diff(entry, staged: staged)
            inspection = output.isEmpty ? "No \(staged ? "staged" : "working tree") changes for \(file)." : output
            inspectionTitle = "\(staged ? "Staged" : "Working diff") · \(file)"
        } else {
            inspection = "Working tree clean. Select a commit or branch to inspect history."
            inspectionTitle = "Working tree"
        }
        showOutput()
        status = "Viewing \(staged ? "staged" : "working tree") diff · read only"
    }

    private func focusPane(_ number: Character) {
        guard modal == nil else { return }
        let target: String
        let title: String
        switch number {
        case "1": target = "files"; title = "Files"
        case "2": target = "branches"; title = "Branches"
        case "3": target = "commits"; title = "Commits"
        case "4": target = "detail"; title = "Inspect"
        default: return
        }
        if host.focus(target, in: view()) { status = "Focus: \(title)" }
    }
}

@main
struct RepositoryDemo {
    @MainActor static func main() async throws {
        let arguments = CommandLine.arguments
        if arguments.contains("--help") {
            print("Usage: RepositoryDemo [--repo PATH] [--no-mouse] [--mono|--16|--256|--truecolor] [--extended-attributes]\nRead-only Git browser. Defaults to the current directory.")
            return
        }
        let directory: String
        if let index = arguments.firstIndex(of: "--repo") {
            guard index + 1 < arguments.count else { throw GitRepository.Failure(message: "--repo requires a path") }
            directory = arguments[index + 1]
        } else { directory = FileManager.default.currentDirectoryPath }
        let repository = try GitRepository(directory: directory)
        let capability: ColorCapability? = arguments.contains("--mono") ? ColorCapability.none
            : arguments.contains("--16") ? .ansi16 : arguments.contains("--256") ? .indexed256
            : arguments.contains("--truecolor") ? .trueColor : nil
        let host = TerminalHost(configuration: .init(colorCapability: capability,
            extendedAttributes: arguments.contains("--extended-attributes"), mouseEnabled: !arguments.contains("--no-mouse")),
            theme: .dusk(colorCapability: capability ?? .detect()))
        let app = try RepositoryApp(host: host, repository: repository, colorCapability: capability ?? .detect())
        app.status = "Ready · read-only repository"
        try await host.run(app)
    }
}
