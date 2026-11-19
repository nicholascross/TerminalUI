import CTerminalSupport
import Foundation
import TerminalUICore
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif canImport(Musl)
    import Musl
#endif

/// Owns one controlling terminal and the process-wide signal wakeup pipe.
/// Operations are serialized by TerminalHost, including across detached I/O tasks.
final class TerminalSession: @unchecked Sendable {
    private enum MouseMode: Int {
        case clicks = 1000
        case clicksAndDrags = 1002
    }

    struct Input {
        var bytes: [UInt8] = []
        var terminate = false
        var endOfFile = false
    }

    private let outputWriter: TerminalOutputWriter
    private var descriptor: Int32 = -1
    private var signalDescriptor: Int32 = -1
    private var original = termios()
    private var needsAttributeRestore = false
    private var enabledScreen = false
    private var acquiredSignals = false
    private var closed = false
    private let alternateScreen: Bool
    private let mouseMode: MouseMode?

    init(configuration: TerminalConfiguration, outputWriter: TerminalOutputWriter = .init()) throws {
        self.outputWriter = outputWriter
        alternateScreen = configuration.alternateScreen
        if configuration.mouseEnabled {
            mouseMode = configuration.mouseMotionEnabled ? .clicksAndDrags : .clicks
        } else {
            mouseMode = nil
        }
        guard ProcessInfo.processInfo.environment["TERM"] != "dumb" else { throw TerminalError.unsupportedTerminal }
        descriptor = open("/dev/tty", O_RDWR | O_NOCTTY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0, isatty(descriptor) == 1 else {
            if descriptor >= 0 { _ = close(descriptor) }
            descriptor = -1
            throw TerminalError.noControllingTerminal
        }
        do {
            guard tcgetattr(descriptor, &original) == 0 else { throw TerminalError.systemCall("tcgetattr", errno) }
            let initialSize = try size()
            guard initialSize.columns > 0, initialSize.rows > 0 else { throw TerminalError.invalidSize }
            signalDescriptor = tui_signals_open()
            guard signalDescriptor >= 0 else { throw TerminalError.systemCall("signals", errno) }
            acquiredSignals = true
            try enterApplicationMode(flushInput: false)
        } catch {
            restore()
            throw error
        }
    }

    func size() throws -> TerminalSize {
        var value = winsize()
        #if canImport(Darwin)
            let result = ioctl(descriptor, TIOCGWINSZ, &value)
        #else
            let result = ioctl(descriptor, UInt(TIOCGWINSZ), &value)
        #endif
        guard result == 0 else { throw TerminalError.systemCall("TIOCGWINSZ", errno) }
        return TerminalSize(columns: Int(value.ws_col), rows: Int(value.ws_row))
    }

    func readInput(timeout: Int32, updateDescriptor: Int32 = -1) throws -> Input {
        #if canImport(Darwin)
            let result = tui_wait_readable_updates(descriptor, signalDescriptor, updateDescriptor, timeout)
            if result < 0 {
                if errno == EINTR { return Input() }
                throw TerminalError.systemCall("select", errno)
            }
            let terminalReady = result & 1 != 0
            let signalReady = result & 2 != 0
        #else
            var descriptors = [pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0),
                               pollfd(fd: signalDescriptor, events: Int16(POLLIN), revents: 0),
                               pollfd(fd: updateDescriptor, events: Int16(POLLIN), revents: 0)]
            let result = poll(&descriptors, nfds_t(descriptors.count), timeout)
            if result < 0 {
                if errno == EINTR { return Input() }
                throw TerminalError.systemCall("poll", errno)
            }
            let terminalReady = descriptors[0].revents & Int16(POLLIN) != 0
            let signalReady = descriptors[1].revents & Int16(POLLIN) != 0
        #endif
        var input = Input()
        if signalReady {
            var signals = [UInt8](repeating: 0, count: 128)
            let count = read(signalDescriptor, &signals, signals.count)
            if count > 0 {
                input.terminate = signals.prefix(count).contains { $0 == UInt8(SIGTERM) || $0 == UInt8(SIGHUP) || $0 == UInt8(SIGINT) }
            }
        }
        if terminationRequested { input.terminate = true }
        if terminalReady {
            var bytes = [UInt8](repeating: 0, count: 4096)
            let count = read(descriptor, &bytes, bytes.count)
            if count > 0 {
                input.bytes = Array(bytes.prefix(count))
            } else if count == 0 {
                input.endOfFile = true
            } else if errno != EAGAIN, errno != EINTR {
                throw TerminalError.systemCall("read", errno)
            }
        }
        #if !canImport(Darwin)
            if descriptors[0].revents & Int16(POLLHUP | POLLERR | POLLNVAL) != 0 { input.endOfFile = true }
        #endif
        return input
    }

    /// Writes one complete transaction; a timeout leaves the screen state unknown.
    func writeAll(_ bytes: [UInt8]) throws {
        try outputWriter.writeAll(bytes, write: { buffer in
            write(descriptor, buffer.baseAddress, buffer.count)
        }, error: { errno }, waitWritable: {
            #if canImport(Darwin)
                let ready = tui_wait_writable(descriptor, 100)
                if ready < 0, errno != EINTR { throw TerminalError.systemCall("select output", errno) }
                return true
            #else
                var target = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
                let ready = poll(&target, 1, 100)
                if ready < 0, errno != EINTR { throw TerminalError.systemCall("poll output", errno) }
                return target.revents & Int16(POLLERR | POLLHUP | POLLNVAL) == 0
            #endif
        })
    }

    /// Requests a clipboard write in the attached terminal using OSC 52.
    func copySelection(_ text: String) throws {
        let encoded = Data(text.utf8).base64EncodedString()
        try writeAll(Array("\u{1b}]52;c;\(encoded)\u{1b}\\".utf8))
    }

    var terminationRequested: Bool { tui_signals_termination_requested() != 0 }

    func suspend() throws {
        // A terminal-generated Ctrl-C goes to the foreground editor as well as the host.
        tui_signals_ignore_interrupt(1)
        try leaveApplicationMode()
        // A command can change termios and exit without restoring it, including during host shutdown.
        needsAttributeRestore = true
    }

    func resume() throws {
        defer { tui_signals_ignore_interrupt(0) }
        try enterApplicationMode(flushInput: true)
    }

    private func enterApplicationMode(flushInput: Bool) throws {
        var raw = original
        cfmakeraw(&raw)
        guard tcsetattr(descriptor, flushInput ? TCSAFLUSH : TCSANOW, &raw) == 0 else {
            throw TerminalError.systemCall("tcsetattr", errno)
        }
        needsAttributeRestore = true
        // Mark before writing so a partially written setup is also reversed.
        enabledScreen = true
        let setup = (alternateScreen ? "\u{1b}[?1049h" : "") + "\u{1b}[?2004h\u{1b}[>4;2m\u{1b}[>1u\u{1b}[?25l"
            + (mouseMode.map { "\u{1b}[?1006h\u{1b}[?\($0.rawValue)h" } ?? "")
        try writeAll(Array(setup.utf8))
    }

    private func leaveApplicationMode() throws {
        let screen = Result {
            guard enabledScreen else { return }
            let reset = (mouseMode.map { "\u{1b}[?\($0.rawValue)l\u{1b}[?1006l" } ?? "")
                + "\u{1b}[0m\u{1b}[<u\u{1b}[>4m\u{1b}[?2004l\u{1b}[?25h" + (alternateScreen ? "\u{1b}[?1049l" : "")
            try writeAll(Array(reset.utf8))
            enabledScreen = false
        }
        if needsAttributeRestore {
            guard tcsetattr(descriptor, TCSANOW, &original) == 0 else {
                throw TerminalError.systemCall("tcsetattr", errno)
            }
            needsAttributeRestore = false
        }
        try screen.get()
    }

    func restore() {
        guard !closed else { return }
        closed = true
        try? leaveApplicationMode()
        if acquiredSignals { tui_signals_close() }
        if descriptor >= 0 { _ = close(descriptor); descriptor = -1 }
    }

    deinit { restore() }
}
