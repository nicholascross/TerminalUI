import ArgumentParser
import TerminalUI
import TerminalUIArgumentParser

struct ConsumerOptions: TerminalApplicationArguments {
    @Option var message = "Hello"
    @OptionGroup var terminal: TerminalOptions
}

@main
@TerminalApplication(arguments: ConsumerOptions.self)
public struct ConsumerApplication {
    public var root: some TerminalView {
        precondition(arguments.message != "do-not-build", "Help and invalid arguments must finish before root construction")
        return Text(arguments.message)
    }
}
