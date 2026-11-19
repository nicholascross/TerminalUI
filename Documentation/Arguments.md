# Command-line arguments

Add typed options with the optional `TerminalUIArgumentParser` product and Apple's `ArgumentParser` product. Plain `@TerminalApplication` applications only need `TerminalUI`.

## Declaring options

Conform to `TerminalApplicationArguments`, declare your options, and include the shared `TerminalOptions` group.

```swift
import ArgumentParser
import TerminalUI
import TerminalUIArgumentParser

struct GreetingOptions: TerminalApplicationArguments {
    @Option(help: "Name to greet.")
    var name = "World"

    @OptionGroup
    var terminal: TerminalOptions
}

@main
@TerminalApplication(arguments: GreetingOptions.self)
struct GreetingApp {
    var root: some TerminalView { GreetingScreen(name: arguments.name) }
}

@TerminalComponent
struct GreetingScreen: TerminalView {
    let name: String
    @ApplicationContext private var application

    var body: some TerminalView {
        Column(spacing: 1) {
            Text("Hello, \(name)!").role(.heading)
            Button("Quit").onActivate { application.stop() }
        }
    }
}
```

The macro provides the `arguments` value, application initialization and terminal configuration. Use Argument Parser's `@Option`, `@Argument` and `@Flag` for application inputs, and `validate()` for input validation.

## Shared options

| Flag | Behaviour |
| --- | --- |
| `--mouse` / `--no-mouse` | Enable or disable mouse input. Default: enabled; the last supplied flag wins. |
| `--copy-on-select` | Copy a drag selection on release in text that opts in. Requires mouse input. |
| `--mouse-drag` | Enable drag reports for features such as panel resizing. Requires mouse input. |
| `--preview` | Print an 80×24 text snapshot without opening a terminal. |
| `-h` / `--help` | Print generated usage information. |

Argument parsing happens before application construction or terminal acquisition. Help and invalid input use Argument Parser's messages and exit codes.

## Terminal configuration

An argument-aware application's configuration comes from `arguments.terminal.configuration`. Declare terminal settings in the options group; the macro rejects an app-level `configuration` property. Theme selection remains an application property.

A plain `@TerminalApplication` uses its own optional `configuration` property and defaults to mouse input disabled.

For programmatic construction, use the generated `init(arguments:)` with parsed options. In tests, `GreetingOptions.parse(["--name", "Ada", "--no-mouse"])` returns typed values without starting the application.

The [repository browser](../Examples/RepositoryDemo/README.md) demonstrates typed arguments in a complete application.
