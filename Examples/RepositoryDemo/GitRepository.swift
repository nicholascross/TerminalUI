import Foundation

/// Read-only Git queries. Arguments are passed directly to Git, never through a shell.
struct GitRepository {
    struct File: Equatable {
        let path: String
        let status: String
    }

    struct Commit: Equatable {
        let hash: String
        let subject: String
    }

    struct Snapshot {
        let branch: String
        let files: [File]
        let branches: [String]
        let commits: [Commit]
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private(set) var directory: String

    init(directory: String) throws {
        self.directory = directory
        self.directory = try run(["rev-parse", "--show-toplevel"]).trimmingCharacters(in: .newlines)
    }

    func snapshot() throws -> Snapshot {
        let status = try run(["status", "--porcelain=v1", "-z", "--untracked-files=all"])
        let entries = status.split(separator: "\0", omittingEmptySubsequences: true)
        var files: [File] = []
        var index = 0
        while index < entries.count {
            let entry = entries[index]
            guard entry.count >= 4 else { index += 1; continue }
            let code = String(entry.prefix(2))
            files.append(File(path: String(entry.dropFirst(3)), status: code))
            // In -z mode rename/copy destinations precede the original path.
            index += code.contains("R") || code.contains("C") ? 2 : 1
        }
        let symbolic = try run(["symbolic-ref", "--quiet", "--short", "HEAD"], allowedExitCodes: [0, 1])
        let branch = symbolic.isEmpty ? "detached HEAD" : symbolic.trimmingCharacters(in: .whitespacesAndNewlines)
        let branches = try run(["for-each-ref", "--format=%(refname:short)", "refs/heads/"])
            .split(separator: "\n").map(String.init)
        let history: String
        if try run(["rev-parse", "--verify", "--quiet", "HEAD"], allowedExitCodes: [0, 1]).isEmpty {
            history = ""
        } else {
            history = try run(["log", "-50", "--format=%H%x00%s"])
        }
        let commits = history.split(separator: "\n").compactMap { line -> Commit? in
            let parts = line.split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            return Commit(hash: String(parts[0]), subject: String(parts[1]))
        }
        return Snapshot(branch: branch, files: files, branches: branches, commits: commits)
    }

    func diff(_ file: File, staged: Bool) throws -> String {
        if file.status == "??" {
            return "Untracked file · no Git diff available.\n\(file.path)"
        }
        return try run(["diff", "--no-ext-diff", "--no-textconv"] + (staged ? ["--cached"] : []) + ["--", file.path])
    }

    func show(commit: String) throws -> String {
        try run(["show", "--no-ext-diff", "--no-textconv", "--format=fuller", "--stat", "--patch", commit, "--"])
    }

    func show(branch: String) throws -> String {
        try run(["log", "-20", "--format=%h %s", "refs/heads/" + branch, "--"])
    }

    private func run(_ arguments: [String], allowedExitCodes: Set<Int32> = [0]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "--no-optional-locks", "--no-pager", "-c", "color.ui=false", "-c", "core.quotePath=false"] + arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        let output = Pipe()
        // Drain one combined pipe before waiting, including for large diffs.
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self)
        guard allowedExitCodes.contains(process.terminationStatus) else {
            throw Failure(message: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return text
    }
}
