/// Semantic styles used by built-in controls and custom widgets.
public struct Theme: Sendable {
    public var borders = BorderCharacters.square
    public var normal = TextStyle()
    public var secondary = TextStyle()
    public var muted = TextStyle(dim: true)
    public var heading = TextStyle(bold: true)
    public var accent = TextStyle(foreground: .cyan)
    public var highlighted = TextStyle(bold: true, underline: true)
    public var info = TextStyle(foreground: .cyan)
    public var success = TextStyle(foreground: .green)
    public var selection = TextStyle(reversed: true)
    public var focused = TextStyle(bold: true, underline: true)
    public var disabled = TextStyle(dim: true, underline: true)
    public var warning = TextStyle(foreground: .yellow, bold: true)
    public var error = TextStyle(foreground: .red, bold: true)
    public var border = TextStyle()
    public var activeBorder = TextStyle(bold: true)
    public var surface = TextStyle()
    public var field = TextStyle()
    public var cursor = TextStyle(reversed: true)
    public var dialog = TextStyle(bold: true)
    public var action = TextStyle(bold: true)
    public var syntaxKeyword = TextStyle(foreground: .magenta, bold: true)
    public var syntaxType = TextStyle(foreground: .cyan)
    public var syntaxFunction = TextStyle(foreground: .brightBlue)
    public var syntaxProperty = TextStyle(foreground: .brightBlue)

    public init() {}
    public static var terminalNative: Theme { Theme() }
    public static var dark: Theme {
        var theme = Theme()
        theme.normal.foreground = .rgb(220, 224, 240)
        theme.secondary.foreground = .rgb(186, 193, 218)
        theme.muted = TextStyle(foreground: .rgb(165, 174, 205))
        theme.accent.foreground = .rgb(125, 180, 255)
        theme.border.foreground = .rgb(150, 164, 200)
        theme.activeBorder = TextStyle(foreground: .rgb(125, 180, 255), bold: true)
        theme.field = theme.normal
        theme.syntaxKeyword = TextStyle(foreground: .rgb(210, 160, 255), bold: true)
        theme.syntaxType.foreground = .rgb(100, 215, 210)
        theme.syntaxFunction.foreground = .rgb(125, 180, 255)
        theme.syntaxProperty.foreground = .rgb(125, 180, 255)
        return theme
    }
    /// An opaque light palette that does not depend on the terminal's default colours.
    public static var light: Theme {
        var theme = Theme()
        theme.normal = TextStyle(foreground: .rgb(35, 42, 60), background: .rgb(248, 249, 252))
        theme.secondary.foreground = .rgb(65, 73, 90)
        theme.muted = TextStyle(foreground: .rgb(90, 96, 110))
        theme.heading = TextStyle(foreground: theme.normal.foreground, bold: true)
        theme.accent.foreground = .rgb(35, 75, 155)
        theme.highlighted = TextStyle(foreground: .rgb(125, 35, 145), background: .rgb(241, 229, 247), bold: true)
        theme.info = TextStyle(foreground: .rgb(0, 90, 125), background: .rgb(223, 241, 249), bold: true)
        theme.success = TextStyle(foreground: .rgb(30, 115, 65))
        theme.warning = TextStyle(foreground: .rgb(140, 90, 0), bold: true)
        theme.error = TextStyle(foreground: .rgb(170, 45, 45), bold: true)
        theme.border.foreground = .rgb(85, 95, 115)
        theme.activeBorder = TextStyle(foreground: .rgb(35, 75, 155), bold: true)
        theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(240, 244, 250))
        theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(255, 255, 255))
        theme.selection = TextStyle(foreground: theme.normal.foreground, background: .rgb(214, 226, 245))
        theme.focused = TextStyle(foreground: theme.accent.foreground, background: theme.selection.background,
                                  bold: true, underline: true)
        theme.disabled = TextStyle(foreground: theme.muted.foreground, underline: true)
        theme.cursor = TextStyle(foreground: theme.normal.foreground, reversed: true)
        theme.dialog = TextStyle(foreground: theme.border.foreground, bold: true)
        theme.action = theme.secondary
        theme.syntaxKeyword = TextStyle(foreground: .rgb(125, 35, 145), bold: true)
        theme.syntaxType.foreground = .rgb(0, 105, 105)
        theme.syntaxFunction.foreground = .rgb(35, 75, 155)
        theme.syntaxProperty.foreground = .rgb(35, 75, 155)
        return theme
    }
    public subscript(role: TextRole) -> TextStyle {
        switch role {
        case .normal: normal
        case .secondary: secondary
        case .muted: muted
        case .heading: heading
        case .accent: accent
        case .highlighted: highlighted
        case .info: info
        case .success: success
        case .selection: selection
        case .focused: focused
        case .disabled: disabled
        case .warning: warning
        case .error: error
        case .border: border
        case .activeBorder: activeBorder
        case .surface: surface
        case .field: field
        case .cursor: cursor
        case .dialog: dialog
        case .action: action
        case .syntaxKeyword: syntaxKeyword
        case .syntaxType: syntaxType
        case .syntaxFunction: syntaxFunction
        case .syntaxProperty: syntaxProperty
        }
    }
}
