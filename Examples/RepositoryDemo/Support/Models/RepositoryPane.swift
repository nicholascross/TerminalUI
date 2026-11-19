import TerminalUI

enum RepositoryPane: String, CaseIterable, MenuItemDefinition {
    case files, branches, commits, inspector

    var id: Self { self }
    var title: String {
        switch self {
        case .files: "Files"
        case .branches: "Branches"
        case .commits: "Commits"
        case .inspector: "Inspect"
        }
    }
}

enum RepositoryCommand: CaseIterable, MenuItemDefinition {
    case refresh, editFile, workingDiff, stagedDiff, selectedCommit, help

    var id: Self { self }
    var menuShortcut: MenuShortcut { .none }
    var title: String {
        switch self {
        case .refresh: "Refresh repository"
        case .editFile: "Open selected file in editor"
        case .workingDiff: "View working tree diff"
        case .stagedDiff: "View staged diff"
        case .selectedCommit: "View selected commit"
        case .help: "Repository help"
        }
    }
}
