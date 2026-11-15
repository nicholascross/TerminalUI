# Applications with command-line arguments

`@TerminalApplication` has two forms. Plain applications use `import TerminalUI` and keep their existing `root`, `theme` and optional `configuration` properties. They do not depend on Argument Parser.

For typed arguments, add the optional `TerminalUIArgumentParser` product and Apple's `ArgumentParser` product to the executable target. Import `ArgumentParser` where you declare options, and `TerminalUIArgumentParser` where you use the argument-aware macro.

```swift
import ArgumentParser
import TerminalUI
import TerminalUIArgumentParser

struct RepositoryOptions: TerminalApplicationArguments {
    @Option(help: "Repository directory.")
    var repo = "."

    @OptionGroup
    var terminal: TerminalOptions
}

@main
@TerminalApplication(arguments: RepositoryOptions.self)
struct RepositoryDemo {
    var root: some TerminalView {
        RepositoryScreen(directory: arguments.repo)
    }

    var theme: Theme { .nord() }
}
```

`RepositoryScreen` is the application's own view. Its initializer is nonthrowing; repository loading, failures and retry belong to the screen's mounted state. See the [repository example](../Examples/RepositoryDemo/README.md).

The macro generates a private `arguments` property, `init(arguments:)`, `configuration` derived from `arguments.terminal.configuration`, and `main()`. There is no handwritten initializer or argument parsing in the app. The generated initializer is also available within the app's module for programmatic construction and tests using parsed options.

`TerminalApplicationArguments` refines `ParsableArguments`. Declare application inputs with Argument Parser's `@Option`, `@Argument` and `@Flag`; use `validate()` for application-specific input validation. The shared group provides:

| Flag | Behavior |
| --- | --- |
| `--preview` | Print an 80×24 snapshot without acquiring a terminal. Default: interactive execution. |
| `--mouse` / `--no-mouse` | Enable or disable mouse input. Default: enabled. If both are supplied, the last one wins. |
| `-h` / `--help` | Argument Parser prints usage and returns success before constructing the application. |

## Configuration ownership

An argument-aware application's terminal configuration comes entirely from `TerminalOptions`. A CLI flag replaces that option's default. The macro rejects an app-level `configuration` property, so there are no competing mouse settings or implicit configuration merges. Calling `makeApplication()` on a programmatically constructed instance uses the same generated configuration as the command-line launcher.

A plain `@TerminalApplication` application continues to configure its host through its own `configuration` property, with the existing framework defaults. Its API and generated entry point are unchanged. Theme selection remains an application property in either form.

## Startup and tests

The argument-aware launcher parses once, then constructs the application and runs or previews it using the parsed options. Help, invalid flags and missing values finish before root construction or terminal acquisition. Parsing and runtime errors use Argument Parser's messages and exit codes. The existing `TerminalApp.run(arguments:)` API remains available for plain applications; the typed launcher does not scan the raw command line a second time.

Use `Options.parse(["--repo", path, "--preview"])` to test valid input and `Options.exitCode(for:)` or `Options.fullMessage(for:)` to inspect thrown parsing failures without exiting the test process. `swift test --filter TerminalUIArgumentParserTests` checks typed injection, shared configuration, validation and preview execution. Macro tests cover generated members and diagnostics. The external API checks compile an argument-aware application outside this package and verify help and errors before root construction.
