import TerminalUICore

/// Settings for the full-screen terminal host.
public struct TerminalConfiguration: Sendable {
    /// Delay used to distinguish Escape from the start of a legacy key sequence.
    public var escapeTimeoutMilliseconds: Int
    /// Maximum accepted size of a bracketed paste in bytes.
    public var pasteLimit: Int
    /// Whether the host uses the alternate screen.
    public var alternateScreen: Bool
    /// Requests mouse clicks and wheel reports. Disabled by default to preserve terminal text selection.
    public var mouseEnabled: Bool
    /// Copies a mouse selection on release in text that opts in. Requires mouse input.
    public var copyOnSelect: Bool

    var mouseSelectionEnabled: Bool { mouseEnabled && copyOnSelect }

    public var colorCapability: ColorCapability?
    public var extendedAttributes: Bool

    public init(
        escapeTimeoutMilliseconds: Int = 30,
        pasteLimit: Int = 1_048_576,
        alternateScreen: Bool = true,
        colorCapability: ColorCapability? = nil,
        extendedAttributes: Bool = false,
        mouseEnabled: Bool = false,
        copyOnSelect: Bool = false,
    ) {
        self.escapeTimeoutMilliseconds = min(5000, max(1, escapeTimeoutMilliseconds))
        self.pasteLimit = max(0, pasteLimit)
        self.alternateScreen = alternateScreen
        self.mouseEnabled = mouseEnabled
        self.copyOnSelect = copyOnSelect
        self.colorCapability = colorCapability
        self.extendedAttributes = extendedAttributes
    }
}
