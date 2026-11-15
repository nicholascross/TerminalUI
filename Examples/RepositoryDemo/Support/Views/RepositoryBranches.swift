import TerminalUI

struct RepositoryBranches: TerminalView {
    let branches: [String]
    let current: String
    @Binding var selection: String?

    var body: some TerminalView {
        Panel("Branches") {
            List(
                id: "branches", rows: branches.map { ListRow(id: $0, title: ($0 == current ? "* " : "  ") + $0) },
                selection: $selection
            )
            .focusTarget(RepositoryPane.branches)
        }
    }
}
