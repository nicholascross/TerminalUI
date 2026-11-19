import TerminalUI

@TerminalComponent
struct RepositoryBrowser: TerminalView {
    private enum Modal { case commands, help }

    @Binding var model: RepositoryViewModel
    @State private var modal: Modal? = nil
    @ApplicationContext private var application

    private var focusedPane: RepositoryPane? { application.focusedValue(of: RepositoryPane.self) }

    var body: some TerminalView {
        let size = application.terminalSize
        Column(spacing: size.rows < 28 ? 0 : 1) {
            RepositoryHeader(
                name: model.repositoryName, branch: model.snapshot.branch,
                changedFiles: model.snapshot.files.count, quit: { application.stop() })
            Row(spacing: 1) {
                MenuBar(
                    id: "navigation", items: RepositoryPane.allCases, activeItem: focusedPane,
                    compact: size.columns < 85
                )
                .id("navigation")
                Button("Commands")
                    .onActivate { modal = .commands }
                    .keyboardShortcut(.controlP)
            }
            RepositoryWorkspace(model: $model)
                .id("workspace")
                .height(.fill())
            Row(spacing: 1) {
                Button("Refresh").onActivate { model.refresh() }
                Button("Working diff").onActivate { model.showWorkingDiff() }
                Button("Staged diff").onActivate { model.showStagedDiff() }
            }
            Column {
                StatusBar(model.status)
                Text(contextualHints).role(.secondary)
                Text("Alt+1–4 panes · Ctrl-P menu · Tab focus · Ctrl-C quit").role(.secondary)
            }
        }
        .overlay {
            if modal == .commands {
                Menu(
                    id: "commands", title: "Repository commands", items: RepositoryCommand.allCases,
                    unavailableReason: unavailableReason, onActivate: { run($0) }
                )
                .onDismiss { modal = nil }
            } else if modal == .help {
                RepositoryHelp(dismiss: { modal = nil })
                    .width(.fixed(min(68, size.columns)))
            }
        }
        .onAction { action in
            switch action {
            case .unhandledKey(.controlC): application.stop()
            case .unhandledKey(.character("e")) where modal == nil && focusedPane == .files: openEditor()
            case .pasteTruncated: model.status = "Paste truncated at configured byte limit"
            default: return false
            }
            return true
        }
    }

    private func run(_ command: RepositoryCommand) {
        modal = nil
        switch command {
        case .refresh: model.refresh()
        case .editFile: openEditor()
        case .workingDiff: model.showWorkingDiff()
        case .stagedDiff: model.showStagedDiff()
        case .selectedCommit: model.showCommit()
        case .help: modal = .help
        }
    }

    private func unavailableReason(_ command: RepositoryCommand) -> String? {
        switch command {
        case .editFile where model.file == nil: "Select a file first"
        case .selectedCommit where model.commit == nil: "No commits yet in this repository"
        default: nil
        }
    }

    private func openEditor() {
        guard let path = model.file else {
            model.status = "Select a file to open in the editor"
            return
        }
        do {
            let arguments = try model.repository.editorArguments(for: path)
            Task { @MainActor in
                do {
                    try await application.runInTerminal("/bin/sh", arguments: arguments)
                    model.refresh()
                } catch is CancellationError {
                    return
                } catch {
                    model.refresh()
                    model.status = "Editor: \(error.localizedDescription)"
                }
            }
        } catch {
            model.status = "Editor: \(error.localizedDescription)"
        }
    }

    private var contextualHints: String {
        if modal != nil { return "Type to filter · Enter open · Esc return" }
        switch focusedPane {
        case .files: return "↑/↓ select a file · e open in editor · Working diff / Staged diff inspect changes"
        case .branches: return "↑/↓ inspect branch history · branch stays checked out"
        case .commits: return "↑/↓ inspect a commit · Newer / Older step through history"
        case .inspector: return "↑/↓ scroll · PgUp/PgDn page · Home/End jump"
        case nil: return "←/→ choose · Enter activate · Tab next control"
        }
    }
}
