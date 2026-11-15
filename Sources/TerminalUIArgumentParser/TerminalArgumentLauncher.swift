import TerminalUI

/// Implementation support for argument-aware @TerminalApplication entry points.
@MainActor
public enum TerminalArgumentLauncher {
    /// Parses once, before constructing the application. Help and failures use Argument Parser's exit handling.
    /// Explicit arguments exclude the executable name, matching Argument Parser's parsing methods.
    public static func run<Arguments: TerminalApplicationArguments, Application: TerminalApplicationDefinition>(
        _ type: Arguments.Type,
        arguments: [String]? = nil,
        makeApplication: (Arguments) -> Application
    ) async {
        do {
            let options = try Arguments.parse(arguments)
            let definition = makeApplication(options)
            let app = definition.makeApplication()
            if options.terminal.preview {
                for line in app.preview() { print(line) }
            } else {
                try await app.run()
            }
        } catch {
            Arguments.exit(withError: error)
        }
    }
}
