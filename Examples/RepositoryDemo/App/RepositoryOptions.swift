import ArgumentParser
import TerminalUIArgumentParser

struct RepositoryOptions: TerminalApplicationArguments {
    @Option(help: "Repository directory. Defaults to the current directory.")
    var repo = "."

    @OptionGroup
    var terminal: TerminalOptions
}
