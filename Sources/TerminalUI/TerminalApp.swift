import TerminalUICore
import TerminalUIRuntime

/// Owns the host and mounted presentation for one application, including terminal-independent previews.
@MainActor
public final class TerminalApp<Root: TerminalView> {
    package let host: TerminalHost
    package let presentation: ComponentApplication
    public var context: TerminalApplicationContext {
        presentation.context
    }

    /// The active theme. Changing it schedules a redraw of the mounted application.
    public var theme: Theme {
        get { context.theme }
        set { context.theme = newValue }
    }

    public init(root: Root, configuration: TerminalConfiguration = .init(), theme: Theme = .init(), diagnostic: (@MainActor (String) -> Void)? = nil)
    {
        host = TerminalHost(configuration: configuration, theme: theme)
        presentation = ComponentApplication(root: root, diagnostic: diagnostic ?? ComponentApplication.reportDiagnostic)
        host.connect(presentation)
    }

    public func invalidate() { presentation.invalidate() }
    public func stop() { presentation.stop() }
    @discardableResult
    public func transaction<Result>(_ work: () throws -> Result) rethrows -> Result { try presentation.transaction(work) }

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
