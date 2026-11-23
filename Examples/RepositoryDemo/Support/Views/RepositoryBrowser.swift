import Foundation
import TerminalUI

@TerminalComponent
struct RepositoryBrowser: TerminalView {
    private enum Modal { case commands, help }
    private enum RefreshNotice { case success(String), failure(String) }

    @Binding var model: RepositoryViewModel
    @State private var modal: Modal? = nil
    @State private var refreshNotice: RefreshNotice? = nil
    @State private var showingRefreshDetails = false
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
                Button("Refresh").onActivate { refreshRepository() }
                Button("Working diff").onActivate { model.showWorkingDiff() }
                Button("Staged diff").onActivate { model.showStagedDiff() }
            }
            Column {
                switch refreshNotice {
                case .success(let id):
                    Banner("Repository refreshed · read only", style: .success, timeout: .seconds(3), id: id)
                case .failure:
                    Banner("Couldn’t refresh the repository.", style: .error, action: .init("Details") {
                        showingRefreshDetails = true
                    })
                case nil:
                    EmptyView()
                }
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
        .choiceDialog(
            id: "refresh-failure", title: "Repository refresh failed", message: refreshError,
            isPresented: $showingRefreshDetails,
            options: [.init(id: "retry", title: "Retry"), .init(id: "dismiss", title: "Dismiss")], initialOption: "retry",
        ) { option in
            if option.id == "retry" {
                refreshRepository()
            } else {
                refreshNotice = nil
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
        case .refresh: refreshRepository()
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

    private var refreshError: String {
        if case .failure(let message) = refreshNotice { return message }
        return ""
    }

    private func refreshRepository() {
        switch model.refresh() {
        case .success: refreshNotice = .success(UUID().uuidString)
        case .failure(let error): refreshNotice = .failure(error.localizedDescription)
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
                    refreshRepository()
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
