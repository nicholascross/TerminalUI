extension Theme {
    /// An opaque Ayu Light palette adapted from Chroma's Base46 preset.
    /// Pass the host's capability when overriding automatic detection.
    public static func ayuLight(colorCapability: ColorCapability = .detect()) -> Theme {
        var theme = Theme()
        theme.borders = .rounded
        if colorCapability == .ansi16 {
            theme.normal = TextStyle(foreground: .black, background: .brightWhite)
            theme.secondary = TextStyle(foreground: .brightBlack)
            theme.muted = theme.secondary
            theme.accent = TextStyle(foreground: .blue)
            theme.info = TextStyle(foreground: .blue, background: .white, bold: true)
            theme.highlighted = TextStyle(foreground: .magenta, background: .white, bold: true)
            theme.success = TextStyle(foreground: .green)
            theme.warning = TextStyle(foreground: .yellow)
            theme.error = TextStyle(foreground: .red)
            theme.border = TextStyle(foreground: .brightBlack)
            theme.surface = theme.normal
            theme.field = TextStyle(foreground: .black, background: .white)
            theme.selection = theme.field
            theme.syntaxKeyword = TextStyle(foreground: .red, bold: true)
            theme.syntaxType = TextStyle(foreground: .blue)
            theme.syntaxFunction = TextStyle(foreground: .cyan)
            theme.syntaxProperty = TextStyle(foreground: .red)
        } else {
            theme.normal = TextStyle(foreground: .rgb(92, 97, 102), background: .rgb(250, 250, 250))
            theme.secondary = TextStyle(foreground: .rgb(82, 87, 92))
            theme.muted = TextStyle(foreground: .rgb(138, 142, 147))
            theme.accent = TextStyle(foreground: .rgb(44, 145, 217))
            theme.info = TextStyle(foreground: .rgb(44, 145, 217), background: .rgb(240, 240, 240), bold: true)
            theme.highlighted = TextStyle(foreground: .rgb(163, 122, 204), background: .rgb(238, 238, 238), bold: true)
            theme.success = TextStyle(foreground: .rgb(134, 179, 0))
            theme.warning = TextStyle(foreground: .rgb(179, 119, 0))
            theme.error = TextStyle(foreground: .rgb(230, 80, 80))
            theme.border = TextStyle(foreground: .rgb(160, 160, 160))
            theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(243, 243, 243))
            theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(240, 240, 240))
            theme.selection = TextStyle(foreground: .rgb(72, 77, 82), background: .rgb(225, 225, 225))
            theme.syntaxKeyword = TextStyle(foreground: .rgb(250, 141, 62), bold: true)
            theme.syntaxType = TextStyle(foreground: .rgb(57, 158, 230))
            theme.syntaxFunction = TextStyle(foreground: .rgb(85, 180, 212))
            theme.syntaxProperty = TextStyle(foreground: .rgb(240, 113, 113))
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
