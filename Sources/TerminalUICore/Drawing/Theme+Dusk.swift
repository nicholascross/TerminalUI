/// An opaque palette with layered surfaces, adapted from the Parallax harness.
extension Theme {
    /// Uses neutral backgrounds at ANSI depth, where terminal palettes are user-defined.
    /// Pass the same capability as the host when overriding automatic detection.
    public static func dusk(colorCapability: ColorCapability = .detect()) -> Theme {
        var theme = Theme()
        theme.borders = .rounded
        theme.normal = TextStyle(foreground: .rgb(227, 229, 241), background: .rgb(23, 24, 33))
        theme.secondary = TextStyle(foreground: .rgb(173, 179, 206))
        theme.muted = TextStyle(foreground: .rgb(133, 139, 166))
        theme.heading = TextStyle(foreground: theme.normal.foreground, bold: true)
        theme.accent = TextStyle(foreground: .rgb(166, 155, 238))
        theme.info = TextStyle(foreground: .rgb(157, 194, 235), background: .rgb(32, 44, 67), bold: true)
        theme.highlighted = TextStyle(foreground: .rgb(201, 162, 243), background: .rgb(49, 37, 66), bold: true)
        theme.success = TextStyle(foreground: .rgb(129, 199, 160))
        theme.warning = TextStyle(foreground: .rgb(226, 186, 112))
        theme.error = TextStyle(foreground: .rgb(225, 139, 145))
        theme.border = TextStyle(foreground: .rgb(85, 92, 121))
        theme.activeBorder = theme.accent
        theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(29, 31, 43))
        theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(38, 40, 57))
        theme.selection = TextStyle(foreground: theme.normal.foreground, background: .rgb(57, 52, 79))
        theme.focused = TextStyle(foreground: theme.accent.foreground, background: theme.selection.background,
                                  bold: true, underline: true)
        theme.disabled = theme.muted
        theme.cursor = TextStyle(foreground: theme.normal.foreground, reversed: true)
        theme.dialog = theme.border
        theme.action = theme.secondary
        theme.syntaxKeyword = TextStyle(foreground: .rgb(201, 162, 243), bold: true)
        theme.syntaxType = TextStyle(foreground: .rgb(129, 199, 190))
        theme.syntaxFunction = TextStyle(foreground: .rgb(157, 194, 235))
        theme.syntaxProperty = theme.syntaxFunction
        if colorCapability == .ansi16 {
            theme.normal = TextStyle(foreground: .brightWhite, background: .black)
            theme.surface = theme.normal
            theme.field = TextStyle(foreground: .brightWhite, background: .brightBlack)
            theme.secondary = TextStyle(foreground: .white)
            theme.muted = theme.secondary
            theme.heading = TextStyle(foreground: .brightWhite, bold: true)
            theme.accent = TextStyle(foreground: .brightMagenta)
            theme.info = TextStyle(foreground: .brightCyan, background: .brightBlack, bold: true)
            theme.highlighted = TextStyle(foreground: .brightMagenta, background: .brightBlack, bold: true)
            theme.success = TextStyle(foreground: .green)
            theme.warning = TextStyle(foreground: .yellow)
            theme.error = TextStyle(foreground: .red)
            theme.border = TextStyle(foreground: .brightBlack)
            theme.activeBorder = theme.accent
            theme.selection = theme.field
            theme.focused = TextStyle(foreground: .brightMagenta, background: .brightBlack, bold: true, underline: true)
            theme.disabled = theme.muted
            theme.cursor = TextStyle(foreground: .brightWhite, reversed: true)
            theme.dialog = theme.border
            theme.action = theme.secondary
        }
        return theme
    }
}
