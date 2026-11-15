extension Theme {
    /// An opaque Dracula palette with purple accents and vivid semantic colours.
    /// Pass the host's capability when overriding automatic detection.
    /// Palette: https://github.com/dracula/dracula-theme
    public static func dracula(colorCapability: ColorCapability = .detect()) -> Theme {
        var theme = Theme.dusk(colorCapability: colorCapability)
        if colorCapability == .ansi16 {
            theme.syntaxKeyword = TextStyle(foreground: .brightMagenta, bold: true)
            theme.syntaxType = TextStyle(foreground: .brightCyan)
            theme.syntaxFunction = TextStyle(foreground: .brightGreen)
            theme.syntaxProperty = TextStyle(foreground: .white)
        } else {
            theme.normal = TextStyle(foreground: .rgb(248, 248, 242), background: .rgb(40, 42, 54))
            theme.secondary = TextStyle(foreground: .rgb(189, 147, 249))
            theme.muted = TextStyle(foreground: .rgb(98, 114, 164))
            theme.accent = TextStyle(foreground: .rgb(189, 147, 249))
            theme.info = TextStyle(foreground: .rgb(139, 233, 253), background: .rgb(68, 71, 90), bold: true)
            theme.highlighted = TextStyle(foreground: .rgb(255, 121, 198), background: .rgb(68, 71, 90), bold: true)
            theme.success = TextStyle(foreground: .rgb(80, 250, 123))
            theme.warning = TextStyle(foreground: .rgb(241, 250, 140))
            theme.error = TextStyle(foreground: .rgb(255, 85, 85))
            theme.border = TextStyle(foreground: .rgb(98, 114, 164))
            theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(40, 42, 54))
            theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(68, 71, 90))
            theme.selection = theme.field
            theme.syntaxKeyword = TextStyle(foreground: .rgb(255, 121, 198), bold: true)
            theme.syntaxType = TextStyle(foreground: .rgb(139, 233, 253))
            theme.syntaxFunction = TextStyle(foreground: .rgb(80, 250, 123))
            theme.syntaxProperty = TextStyle(foreground: .rgb(248, 248, 242))
        }
        theme.heading = TextStyle(foreground: theme.normal.foreground, bold: true)
        theme.activeBorder = theme.accent
        theme.focused = TextStyle(foreground: theme.accent.foreground, background: theme.selection.background,
                                  bold: true, underline: true)
        theme.disabled = theme.muted
        theme.cursor = TextStyle(foreground: theme.normal.foreground, reversed: true)
        theme.dialog = theme.border
        theme.action = theme.secondary
        return theme
    }
}
