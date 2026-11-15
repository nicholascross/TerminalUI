import Foundation
import Testing
import TerminalUIEngine
@testable import RepositoryDemo

struct GitRepositoryTests {
    @Test func queriesPreserveIndexWorktreeAndBranch() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        try fixture.git(["config", "user.name", "Demo Test"])
        try fixture.git(["config", "user.email", "demo@example.test"])
        try fixture.write("file with spaces.txt", "original\n")
        try fixture.git(["add", "."])
        try fixture.git(["commit", "-m", "Initial commit", "-m", "Full message body."])
        try fixture.git(["branch", "feature/demo"])
        try fixture.write("file with spaces.txt", "staged\n")
        try fixture.git(["add", "."])
        try fixture.write("file with spaces.txt", "working\n")
        try fixture.write("untracked\nname.txt", "new\n")
        let before = try fixture.git(["status", "--porcelain=v1", "-z"])
        let indexBefore = try Data(contentsOf: fixture.url.appendingPathComponent(".git/index"))
        let repository = try GitRepository(directory: fixture.url.path)
        let snapshot = try repository.snapshot()
        #expect(snapshot.branch == "main")
        #expect(snapshot.branches == ["feature/demo", "main"])
        #expect(snapshot.commits.first?.subject == "Initial commit")
        let file = try #require(snapshot.files.first { $0.path == "file with spaces.txt" })
        #expect(file.status == "MM")
        #expect(try repository.diff(file, staged: false).contains("+working"))
        #expect(try repository.diff(file, staged: true).contains("+staged"))
        let patch = try repository.show(commit: #require(snapshot.commits.first?.hash))
        #expect(patch.contains("Initial commit"))
        #expect(patch.contains("Full message body."))
        #expect(patch.contains("Author:     Demo Test"))
        #expect(patch.contains("AuthorDate:"))
        #expect(patch.contains("file with spaces.txt"))
        #expect(patch.contains("+original"))
        #expect(try repository.show(branch: "feature/demo").contains("Initial commit"))
        #expect(snapshot.files.contains { $0.path == "untracked\nname.txt" && $0.status == "??" })
        #expect(try fixture.git(["status", "--porcelain=v1", "-z"]) == before)
        #expect(try Data(contentsOf: fixture.url.appendingPathComponent(".git/index")) == indexBefore)
        #expect(try fixture.git(["branch", "--show-current"]).trimmingCharacters(in: .newlines) == "main")
        #expect(try String(contentsOf: fixture.url.appendingPathComponent("file with spaces.txt"), encoding: .utf8) == "working\n")
    }

    @Test func emptyDetachedAndRenamedRepositories() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        let repository = try GitRepository(directory: fixture.url.path)
        let empty = try repository.snapshot()
        #expect(empty.branch == "main")
        #expect(empty.files.isEmpty && empty.commits.isEmpty)
        try fixture.git(["config", "user.name", "Demo Test"])
        try fixture.git(["config", "user.email", "demo@example.test"])
        try fixture.write("old.txt", "hello\n")
        try fixture.git(["add", "."])
        try fixture.git(["commit", "-m", "Initial"])
        try fixture.git(["mv", "old.txt", "new.txt"])
        let renamed = try repository.snapshot()
        #expect(renamed.files == [.init(path: "new.txt", status: "R ")])
        #expect(try repository.diff(renamed.files[0], staged: true).contains("new.txt"))
        try fixture.git(["checkout", "--detach"])
        #expect(try repository.snapshot().branch == "detached HEAD")
        let nested = fixture.url.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        #expect(try GitRepository(directory: nested.path).directory == fixture.url.path)
    }

    @Test @MainActor func commitViewerHandlesEmptyHistoryNavigationAndRefresh() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.git(["init", "-b", "main"])
        try fixture.git(["config", "user.name", "Demo Test"])
        try fixture.git(["config", "user.email", "demo@example.test"])
        let repository = try GitRepository(directory: fixture.url.path)
        let app = try RepositoryApp(host: TerminalHost(), repository: repository)
        app.handle(.activated("inspect.commit"))
        #expect(app.detail == "commit")
        #expect(app.commitInspection == "No commits yet in this repository.")

        try fixture.write("file.txt", "first\n")
        try fixture.git(["add", "."])
        try fixture.git(["commit", "-m", "First commit", "-m", "Full body"])
        app.handle(.activated("refresh"))
        let first = try #require(app.commit)
        #expect(app.detail == "commit")
        #expect(app.commitInspection.contains("Full body"))
        #expect(app.commitInspection.contains("+first"))
        try fixture.write("file.txt", "second\n")
        try fixture.git(["add", "."])
        try fixture.git(["commit", "-m", "Second commit"])
        app.handle(.activated("refresh"))
        #expect(app.commit == first)
        app.handle(.activated("commit.newer"))
        #expect(app.commit != first)
        #expect(app.commitInspection.contains("Second commit"))
        #expect(app.commitInspection.contains("+second"))
        app.handle(.activated("commit.older"))
        #expect(app.commit == first)
        app.handle(.activated("commit.older"))
        #expect(app.commit == first)
        app.handle(.selectionChanged("detail", "source"))
        app.handle(.selectionChanged("detail", "commit"))
        #expect(app.commitInspection.contains("Full body"))
        let cleanApp = try RepositoryApp(host: TerminalHost(), repository: repository)
        #expect(cleanApp.detail == "commit")
        #expect(cleanApp.commitInspection.contains("Second commit"))
    }

    @Test func invalidRepositoryReportsGitError() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        #expect(throws: GitRepository.Failure.self) { try GitRepository(directory: fixture.url.path) }
    }
}

private struct Fixture {
    let url: URL
    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: url) }
    func write(_ path: String, _ value: String) throws {
        try value.write(to: url.appendingPathComponent(path), atomically: true, encoding: .utf8)
    }
    @discardableResult func git(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", url.path] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw GitRepository.Failure(message: String(decoding: data, as: UTF8.self))
        }
        return String(decoding: data, as: UTF8.self)
    }
}
