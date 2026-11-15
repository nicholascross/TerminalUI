extension Theme {
    /// An opaque Tokyo Night (Night variant) palette with blue and violet accents.
    /// Pass the host's capability when overriding automatic detection.
    /// Palette: https://github.com/folke/tokyonight.nvim
    public static func tokyoNight(colorCapability: ColorCapability = .detect()) -> Theme {
        var theme = Theme.dusk(colorCapability: colorCapability)
        if colorCapability == .ansi16 {
            theme.accent = TextStyle(foreground: .brightBlue)
            theme.syntaxKeyword = TextStyle(foreground: .brightMagenta, bold: true)
            theme.syntaxType = TextStyle(foreground: .brightCyan)
            theme.syntaxFunction = TextStyle(foreground: .brightBlue)
            theme.syntaxProperty = TextStyle(foreground: .white)
        } else {
            theme.normal = TextStyle(foreground: .rgb(192, 202, 245), background: .rgb(26, 27, 38))
            theme.secondary = TextStyle(foreground: .rgb(169, 177, 214))
            theme.muted = TextStyle(foreground: .rgb(115, 122, 162))
            theme.accent = TextStyle(foreground: .rgb(122, 162, 247))
            theme.info = TextStyle(foreground: .rgb(125, 207, 255), background: .rgb(31, 34, 49), bold: true)
            theme.highlighted = TextStyle(foreground: .rgb(187, 154, 247), background: .rgb(41, 46, 66), bold: true)
            theme.success = TextStyle(foreground: .rgb(158, 206, 106))
            theme.warning = TextStyle(foreground: .rgb(224, 175, 104))
            theme.error = TextStyle(foreground: .rgb(247, 118, 142))
            theme.border = TextStyle(foreground: .rgb(84, 92, 126))
            theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(22, 22, 30))
            theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(41, 46, 66))
            theme.selection = TextStyle(foreground: theme.normal.foreground, background: .rgb(40, 52, 87))
            theme.syntaxKeyword = TextStyle(foreground: .rgb(187, 154, 247), bold: true)
            theme.syntaxType = TextStyle(foreground: .rgb(125, 207, 255))
            theme.syntaxFunction = TextStyle(foreground: .rgb(122, 162, 247))
            theme.syntaxProperty = TextStyle(foreground: .rgb(169, 177, 214))
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
