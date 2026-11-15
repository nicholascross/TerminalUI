import ArgumentParser
import TerminalUI

/// Shared flags for an argument-aware terminal application. Mouse input is enabled by default.
public struct TerminalOptions: ParsableArguments {
    @Flag(help: "Print a snapshot without opening the terminal.")
    public var preview = false

    @Flag(inversion: .prefixedNo, help: "Enable or disable mouse input.")
    public var mouse = true

    public init() {}

    /// The sole terminal configuration used by an argument-aware application.
    public var configuration: TerminalConfiguration {
        .init(mouseEnabled: mouse)
    }
}
