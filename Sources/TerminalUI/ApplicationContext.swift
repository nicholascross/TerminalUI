import TerminalUIComponentRuntime

/// Installed by @TerminalComponent alongside @State; available in component bodies and event handlers.
@MainActor
@propertyWrapper
public struct ApplicationContext {
    private var value: TerminalApplicationContext?

    public init() {}

    public var wrappedValue: TerminalApplicationContext {
        guard let value else {
            preconditionFailure("@ApplicationContext must be installed by @TerminalComponent before reading its value")
        }
        return value
    }

    // swiftlint:disable:next identifier_name
    public mutating func _install(in installation: StateInstallation, key _: String) {
        guard let services = installation.context.applicationServices else {
            preconditionFailure("@ApplicationContext requires a ComponentApplication")
        }
        value = TerminalApplicationContext(services: services)
    }
}
