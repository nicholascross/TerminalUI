import ArgumentParser
import TerminalUI
import TerminalUIArgumentParser
import Testing

private struct ExampleOptions: TerminalApplicationArguments {
    @Option var repo = "."
    @OptionGroup var terminal: TerminalOptions

    mutating func validate() throws {
        if repo.isEmpty { throw ValidationError("Repository path must not be empty.") }
    }
}

@TerminalApplication(arguments: ExampleOptions.self)
private struct ExampleApplication {
    var root: some TerminalView { Text(arguments.repo) }
}

@TerminalApplication
private struct PlainApplication {
    var root: some TerminalView { Text("No arguments") }
    var configuration: TerminalConfiguration { .init(pasteLimit: 512, mouseEnabled: false) }
}

@MainActor
struct ArgumentTests {
    @Test func plainApplicationsRemainUnchangedWhenTheIntegrationIsImported() {
        #expect(PlainApplication().makeApplication().preview()[0].hasPrefix("No arguments"))
        #expect(PlainApplication().configuration.pasteLimit == 512)
        #expect(!PlainApplication().configuration.mouseEnabled)
    }

    @Test func parsedArgumentsReachTheGeneratedInitializerAndRoot() throws {
        let options = try ExampleOptions.parse(["--repo", "my-repository", "--preview", "--no-mouse"])
        let application = ExampleApplication(arguments: options)
        #expect(application.makeApplication().preview()[0].hasPrefix("my-repository"))
        #expect(options.terminal.preview)
        #expect(options.terminal.mouse == false)
        #expect(!application.configuration.mouseEnabled)
    }

    @Test func sharedFlagsAreTheOnlySourceOfArgumentApplicationConfiguration() throws {
        let defaults = try ExampleOptions.parse([])
        let omitted = ExampleApplication(arguments: defaults).configuration
        #expect(omitted.mouseEnabled)
        #expect(!omitted.copyOnSelect)
        #expect(!defaults.terminal.preview)
        let withCopy = try ExampleOptions.parse(["--copy-on-select"])
        #expect(ExampleApplication(arguments: withCopy).configuration.copyOnSelect)
        for (flags, enabled) in [(["--no-mouse"], false), (["--mouse"], true), (["--no-mouse", "--mouse"], true)] {
            let options = try ExampleOptions.parse(flags)
            #expect(ExampleApplication(arguments: options).configuration.mouseEnabled == enabled)
            #expect(options.terminal.configuration.mouseEnabled == enabled)
        }
    }

    @Test func helpAndValidationUseArgumentParserSemantics() {
        for arguments in [["--help"], ["--unknown"], ["--repo"], ["--repo", ""]] {
            do {
                _ = try ExampleOptions.parse(arguments)
                Issue.record("Expected parsing to stop for \(arguments)")
            } catch {
                #expect(ExampleOptions.exitCode(for: error).rawValue == (arguments == ["--help"] ? 0 : 64))
                #expect(!ExampleOptions.fullMessage(for: error).isEmpty)
            }
        }
    }

    @Test func typedLauncherUsesSuppliedArgumentsForPreviewWithoutACommandLineRescan() async {
        var received: String?
        await TerminalArgumentLauncher.run(ExampleOptions.self, arguments: ["--repo", "typed-preview", "--preview"]) { options in
            received = options.repo
            return ExampleApplication(arguments: options)
        }
        #expect(received == "typed-preview")
    }
}
