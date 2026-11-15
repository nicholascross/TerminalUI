extension Theme {
    /// An opaque Nord palette with polar backgrounds and frost-blue accents.
    /// Pass the host's capability when overriding automatic detection.
    /// Palette: https://www.nordtheme.com/docs/colors-and-palettes/
    public static func nord(colorCapability: ColorCapability = .detect()) -> Theme {
        var theme = Theme.dusk(colorCapability: colorCapability)
        if colorCapability == .ansi16 {
            theme.accent = TextStyle(foreground: .brightCyan)
            theme.highlighted.foreground = .brightCyan
            theme.syntaxKeyword = TextStyle(foreground: .brightBlue, bold: true)
            theme.syntaxType = TextStyle(foreground: .cyan)
            theme.syntaxFunction = TextStyle(foreground: .brightCyan)
            theme.syntaxProperty = TextStyle(foreground: .white)
        } else {
            theme.normal = TextStyle(foreground: .rgb(216, 222, 233), background: .rgb(46, 52, 64))
            theme.secondary = TextStyle(foreground: .rgb(229, 233, 240))
            theme.muted = TextStyle(foreground: .rgb(129, 161, 193))
            theme.accent = TextStyle(foreground: .rgb(136, 192, 208))
            theme.info = TextStyle(foreground: .rgb(136, 192, 208), background: .rgb(59, 66, 82), bold: true)
            theme.highlighted = TextStyle(foreground: .rgb(180, 142, 173), background: .rgb(67, 76, 94), bold: true)
            theme.success = TextStyle(foreground: .rgb(163, 190, 140))
            theme.warning = TextStyle(foreground: .rgb(235, 203, 139))
            theme.error = TextStyle(foreground: .rgb(191, 97, 106))
            theme.border = TextStyle(foreground: .rgb(76, 86, 106))
            theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(59, 66, 82))
            theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(67, 76, 94))
            theme.selection = TextStyle(foreground: .rgb(236, 239, 244), background: .rgb(76, 86, 106))
            theme.syntaxKeyword = TextStyle(foreground: .rgb(129, 161, 193), bold: true)
            theme.syntaxType = TextStyle(foreground: .rgb(143, 188, 187))
            theme.syntaxFunction = TextStyle(foreground: .rgb(136, 192, 208))
            theme.syntaxProperty = TextStyle(foreground: .rgb(216, 222, 233))
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
