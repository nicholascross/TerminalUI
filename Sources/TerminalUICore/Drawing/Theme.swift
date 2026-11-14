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
    public static var light: Theme {
        var theme = Theme()
        theme.normal.foreground = .rgb(35, 42, 60)
        theme.secondary.foreground = .rgb(65, 73, 90)
        theme.muted = TextStyle(foreground: .rgb(90, 96, 110))
        theme.accent.foreground = .rgb(35, 75, 155)
        theme.border.foreground = .rgb(85, 95, 115)
        theme.activeBorder = TextStyle(foreground: .rgb(35, 75, 155), bold: true)
        theme.field = theme.normal
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
