import TerminalUICore
import TerminalUIRuntime

/// Declarative application settings. @TerminalApplication supplies conformance and the entry method.
@MainActor
public protocol TerminalApplicationDefinition {
    associatedtype Root: TerminalView
    var root: Root { get }
    var configuration: TerminalConfiguration { get }
    var theme: Theme { get }
}

public extension TerminalApplicationDefinition {
    var configuration: TerminalConfiguration {
        .init()
    }

    var theme: Theme {
        .init()
    }

    func makeApplication() -> TerminalApp<Root> {
        TerminalApp(root: root, configuration: configuration, theme: theme)
    }
}

/// Declares a terminal application. Combine with @main on the executable's entry type.
@attached(member, names: named(main))
@attached(memberAttribute)
@attached(extension, conformances: TerminalApplicationDefinition)
public macro TerminalApplication() = #externalMacro(module: "TerminalUIComponentMacros", type: "TerminalApplicationMacro")
