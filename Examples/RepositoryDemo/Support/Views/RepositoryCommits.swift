import TerminalUI

struct RepositoryCommits: TerminalView {
    let commits: [GitRepository.Commit]
    @Binding var selection: String?
    let inspect: () -> Void

    var body: some TerminalView {
        Panel(commits.isEmpty ? "Commits · no commits yet" : "Commits") {
            Table(
                id: "commits", columns: [TableColumn("Hash", width: .fixed(7)), TableColumn("Subject", width: .fill())],
                rows: commits.map { TableRow(id: $0.hash, cells: [String($0.hash.prefix(7)), $0.subject]) },
                selection: $selection
            )
            .focusTarget(RepositoryPane.commits)
            .onSubmit { inspect() }
        }
    }
}
