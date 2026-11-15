import TerminalUI

@TerminalComponent
struct RepositoryWorkspace: TerminalView {
    @Binding var model: RepositoryViewModel
    @ApplicationContext private var application

    var body: some TerminalView {
        let size = application.terminalSize
        let compact = size.columns < 85
        Stack(axis: compact ? .vertical : .horizontal, spacing: 1) {
            sidebar.layoutSizing(
                width: compact ? .automatic : .flexible(weight: 2),
                height: compact ? .fixed(max(12, (size.rows - 10) / 2)) : .automatic)
            inspector.layoutSizing(
                width: compact ? .automatic : .flexible(weight: 3),
                height: compact ? .flexible() : .automatic)
        }
    }

    private var sidebar: some TerminalView {
        Column {
            RepositoryFiles(
                files: model.snapshot.files,
                selection: Binding(get: { model.file }, set: { model.selectFile($0) }),
                inspect: { model.showWorkingDiff() }
            )
            .height(.fill(weight: 2))
            RepositoryBranches(
                branches: model.snapshot.branches, current: model.snapshot.branch,
                selection: Binding(get: { model.branch }, set: { model.selectBranch($0) })
            )
            .height(.fixed(4))
            RepositoryCommits(
                commits: model.snapshot.commits,
                selection: Binding(get: { model.commit }, set: { model.selectCommit($0) }),
                inspect: { model.showCommit() }
            )
            .height(.fill(weight: 2))
        }
    }

    private var inspector: some TerminalView {
        RepositoryInspector(
            title: model.inspectionTitle, output: model.output,
            revision: model.outputRevision, showsCommit: model.inspection == .commit,
            hasNewer: model.hasNewerCommit, hasOlder: model.hasOlderCommit,
            newer: { model.moveCommit(by: -1) }, older: { model.moveCommit(by: 1) })
    }
}
