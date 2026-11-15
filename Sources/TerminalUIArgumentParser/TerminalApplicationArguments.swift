import ArgumentParser
import TerminalUI

/// Application arguments with a shared group of terminal flags.
/// Declare `@OptionGroup var terminal: TerminalOptions` alongside application-specific options.
public protocol TerminalApplicationArguments: ParsableArguments {
    var terminal: TerminalOptions { get }
}

/// Declares an application with typed command-line arguments. The macro generates a private
/// `arguments` property, `init(arguments:)`, configuration from `arguments.terminal`, and an entry point
/// that parses before constructing the app. Declare terminal settings only in the options group.
@attached(member, names: named(arguments), named(init), named(configuration), named(main))
@attached(memberAttribute)
@attached(extension, conformances: TerminalApplicationDefinition)
public macro TerminalApplication<Arguments: TerminalApplicationArguments>(arguments: Arguments.Type) =
    #externalMacro(module: "TerminalUIComponentMacros", type: "TerminalApplicationMacro")
