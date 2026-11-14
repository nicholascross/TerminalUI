import TerminalUICore
import TerminalUIRuntime

/// Owns the host and mounted presentation for one application, including terminal-independent previews.
@MainActor
public final class TerminalApp<Root: TerminalView> {
    public let host: TerminalHost
    public let presentation: ComponentApplication
    public var context: TerminalApplicationContext {
        presentation.context
    }

    public init(root: Root, configuration: TerminalConfiguration = .init(), theme: Theme = .init()) {
        host = TerminalHost(configuration: configuration, theme: theme)
        presentation = ComponentApplication(root: root)
        host.connect(presentation)
    }

    public func run() async throws {
        try await host.run(presentation)
    }

    /// The generated entry point supports --preview without opening the controlling terminal.
    public func run(arguments: [String]) async throws {
        if arguments.contains("--preview") {
            for line in preview() {
                print(line)
            }
        } else {
            try await run()
        }
    }

    public func preview(width: Int = 80, height: Int = 24) -> [String] {
        host.preview(presentation, width: width, height: height)
    }
}
