import CTerminalSupport
import Dispatch
import Foundation
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// A failure requesting, launching, or running a foreground terminal command.
public enum TerminalCommandError: LocalizedError, Equatable, Sendable {
    case sessionNotRunning
    case commandInProgress
    case invalidArguments
    case launchFailed(executable: String, code: Int32)
    case exited(Int32)
    case signalled(Int32)

    public var errorDescription: String? {
        switch self {
        case .sessionNotRunning: "A running terminal session is required"
        case .commandInProgress: "A terminal command is already in progress"
        case .invalidArguments: "A terminal command requires a nonempty executable and arguments without NUL bytes"
        case let .launchFailed(executable, code): "Could not launch \(executable): \(String(cString: strerror(code)))"
        case let .exited(status): "Command exited with status \(status)"
        case let .signalled(signal): "Command terminated by signal \(signal)"
        }
    }
}

struct TerminalCommand {
    let executable: String
    let arguments: [String]

    init(executable: String, arguments: [String]) throws {
        guard !executable.isEmpty, !executable.utf8.contains(0),
              !arguments.contains(where: { $0.utf8.contains(0) })
        else { throw TerminalCommandError.invalidArguments }
        self.executable = executable
        self.arguments = arguments
    }

    @MainActor
    func run(shouldCancel: () -> Bool) async throws {
        let child = try spawn()
        let clock = ContinuousClock()
        var killAfter: ContinuousClock.Instant?
        var cancelled = false
        while true {
            var status: Int32 = 0
            var signal: Int32 = 0
            switch tui_command_poll(child, &status, &signal) {
            case -1: throw TerminalError.systemCall("waitpid", errno)
            case 1:
                if cancelled || shouldCancel() { throw CancellationError() }
                if signal != 0 { throw TerminalCommandError.signalled(signal) }
                if status != 0 { throw TerminalCommandError.exited(status) }
                return
            default: break
            }
            if !cancelled, shouldCancel() {
                cancelled = true
                _ = kill(child, SIGTERM)
                killAfter = clock.now.advanced(by: .seconds(1))
            } else if let deadline = killAfter, clock.now >= deadline {
                _ = kill(child, SIGKILL)
                killAfter = nil
            }
            // Wait for the child even after task cancellation so the editor releases the TTY first.
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(30)) {
                    continuation.resume()
                }
            }
        }
    }

    private func spawn() throws -> pid_t {
        var argv = ([executable] + arguments).map { strdup($0) }
        defer { for argument in argv { free(argument) } }
        guard argv.allSatisfy({ $0 != nil }) else {
            throw TerminalCommandError.launchFailed(executable: executable, code: ENOMEM)
        }
        argv.append(nil)
        var child: pid_t = 0
        let error = tui_command_spawn(&child, argv)
        guard error == 0 else { throw TerminalCommandError.launchFailed(executable: executable, code: error) }
        return child
    }
}
