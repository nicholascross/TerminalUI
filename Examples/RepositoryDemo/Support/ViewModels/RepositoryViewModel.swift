import Foundation

/// Application-owned repository state. The screen keeps this value in a mounted State slot.
struct RepositoryViewModel {
    enum Inspection { case workingTree, staged, branch, commit }

    let repository: GitRepository
    private(set) var snapshot: GitRepository.Snapshot
    private(set) var file: String?
    private(set) var branch: String?
    private(set) var commit: String?
    private(set) var inspection = Inspection.workingTree
    private(set) var inspectionTitle = "Working tree"
    private(set) var output = ""
    private(set) var outputRevision = 0
    var status = "Ready · read-only repository"

    init(repository: GitRepository) throws {
        self.repository = repository
        snapshot = try repository.snapshot()
        file = snapshot.files.first?.path
        branch = snapshot.branch
        commit = snapshot.commits.first?.hash
        if file == nil, commit != nil { try inspectCommit() } else { try inspectFile(staged: false) }
        status = "Ready · read-only repository"
    }

    var repositoryName: String { URL(fileURLWithPath: repository.directory).lastPathComponent }
    var commitIndex: Int? { snapshot.commits.firstIndex { $0.hash == commit } }
    var hasNewerCommit: Bool { commitIndex.map { $0 > 0 } ?? false }
    var hasOlderCommit: Bool { commitIndex.map { $0 + 1 < snapshot.commits.count } ?? false }

    mutating func selectFile(_ path: String?) {
        file = path
        showWorkingDiff()
    }

    mutating func selectBranch(_ name: String?) {
        branch = name
        perform { try $0.inspectBranch() }
    }

    mutating func selectCommit(_ hash: String?) {
        commit = hash
        showCommit()
    }

    mutating func showWorkingDiff() { perform { try $0.inspectFile(staged: false) } }
    mutating func showStagedDiff() { perform { try $0.inspectFile(staged: true) } }
    mutating func showCommit() { perform { try $0.inspectCommit() } }

    mutating func moveCommit(by offset: Int) {
        guard let index = commitIndex, snapshot.commits.indices.contains(index + offset) else { return }
        selectCommit(snapshot.commits[index + offset].hash)
    }

    @discardableResult
    mutating func refresh() -> Result<Void, Error> {
        let result = perform { model in
            model.snapshot = try model.repository.snapshot()
            if !model.snapshot.files.contains(where: { $0.path == model.file }) {
                model.file = model.snapshot.files.first?.path
            }
            if !model.snapshot.branches.contains(where: { $0 == model.branch }) {
                model.branch =
                    model.snapshot.branches.first { $0 == model.snapshot.branch }
                    ?? model.snapshot.branches.first
            }
            if !model.snapshot.commits.contains(where: { $0.hash == model.commit }) {
                model.commit = model.snapshot.commits.first?.hash
            }
            switch model.inspection {
            case .workingTree: try model.inspectFile(staged: false)
            case .staged: try model.inspectFile(staged: true)
            case .branch: try model.inspectBranch()
            case .commit: try model.inspectCommit()
            }
        }
        if case .failure = result { status = "Showing last loaded data · read only" }
        return result
    }

    @discardableResult
    private mutating func perform(_ operation: (inout Self) throws -> Void) -> Result<Void, Error> {
        var next = self
        do {
            try operation(&next)
            self = next
            return .success(())
        } catch {
            status = "Git error: \(error.localizedDescription)"
            return .failure(error)
        }
    }

    private mutating func inspectFile(staged: Bool) throws {
        let title: String
        let text: String
        if let entry = snapshot.files.first(where: { $0.path == file }) {
            let diff = try repository.diff(entry, staged: staged)
            text = diff.isEmpty ? "No \(staged ? "staged" : "working tree") changes for \(entry.path)." : diff
            title = "\(staged ? "Staged" : "Working diff") · \(entry.path)"
        } else {
            text = "Working tree clean. Select a commit or branch to inspect history."
            title = "Working tree"
        }
        setOutput(text, title: title, inspection: staged ? .staged : .workingTree)
        status = "Viewing \(staged ? "staged" : "working tree") diff · read only"
    }

    private mutating func inspectBranch() throws {
        let text = try branch.map { try repository.show(branch: $0) } ?? "No branches yet in this repository."
        setOutput(text, title: branch.map { "Branch · \($0)" } ?? "Branches", inspection: .branch)
        status = branch.map { "Inspecting branch \($0)" } ?? "No branches yet"
    }

    private mutating func inspectCommit() throws {
        let text = try commit.map { try repository.show(commit: $0) } ?? "No commits yet in this repository."
        setOutput(text, title: commit.map { "Commit · \($0.prefix(7))" } ?? "Commits", inspection: .commit)
        status = commit.map { "Selected commit \($0.prefix(7))" } ?? "No commits yet"
    }

    private mutating func setOutput(_ text: String, title: String, inspection: Inspection) {
        output = text
        inspectionTitle = title
        self.inspection = inspection
        outputRevision += 1
    }
}
