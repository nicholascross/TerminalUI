import TerminalUI

@TerminalComponent
struct RepositoryFiles: TerminalView {
    let files: [GitRepository.File]
    @Binding var selection: String?
    let inspect: () -> Void
    @State private var filter = ""

    private var filteredFiles: [GitRepository.File] {
        files.filter { filter.isEmpty || $0.path.localizedCaseInsensitiveContains(filter) }
    }

    var body: some TerminalView {
        Panel("Files · \(files.count) changed") {
            Column {
                TextField(id: "filter", text: $filter, placeholder: "Filter files")
                List(
                    id: "files", rows: filteredFiles.map { ListRow(id: $0.path, title: "\($0.status) \($0.path)") },
                    selection: $selection
                )
                .focusTarget(RepositoryPane.files)
                .initialFocus()
                .onSubmit { inspect() }
                .height(.fill())
            }
        }
    }
}
