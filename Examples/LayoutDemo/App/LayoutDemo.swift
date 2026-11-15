import Foundation
import LayoutDemoSupport
import TerminalUI

@main
@TerminalApplication
struct LayoutDemo {
    var root: some TerminalView {
        LayoutScreen()
    }

    var theme: Theme {
        .nord()
    }

    var configuration: TerminalConfiguration {
        .init(mouseEnabled: !CommandLine.arguments.contains("--no-mouse"))
    }
}
