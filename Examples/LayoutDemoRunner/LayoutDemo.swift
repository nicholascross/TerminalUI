import Foundation
import LayoutDemoSupport
import TerminalUIComponents

@main
@TerminalApplication
struct LayoutDemo {
    var root: some TerminalView {
        LayoutScreen()
    }

    var theme: Theme {
        .dusk()
    }

    var configuration: TerminalConfiguration {
        .init(mouseEnabled: !CommandLine.arguments.contains("--no-mouse"))
    }
}
