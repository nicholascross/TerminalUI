import RepositoryDemoSupport
import TerminalUI
import TerminalUIArgumentParser

@main
@TerminalApplication(arguments: RepositoryOptions.self)
struct RepositoryDemo {
    var root: some TerminalView {
        RepositoryScreen(directory: arguments.repo)
    }

    var theme: Theme { .nord() }
}
