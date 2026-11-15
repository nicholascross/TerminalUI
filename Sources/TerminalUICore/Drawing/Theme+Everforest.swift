extension Theme {
    /// An opaque dark Everforest palette adapted from Chroma's Base46 preset.
    /// Pass the host's capability when overriding automatic detection.
    public static func everforest(colorCapability: ColorCapability = .detect()) -> Theme {
        var theme = Theme.dusk(colorCapability: colorCapability)
        if colorCapability == .ansi16 {
            theme.accent = TextStyle(foreground: .green)
            theme.highlighted.foreground = .brightGreen
            theme.syntaxKeyword = TextStyle(foreground: .red, bold: true)
            theme.syntaxType = TextStyle(foreground: .cyan)
            theme.syntaxFunction = TextStyle(foreground: .green)
            theme.syntaxProperty = TextStyle(foreground: .brightCyan)
        } else {
            theme.normal = TextStyle(foreground: .rgb(211, 198, 170), background: .rgb(43, 51, 57))
            theme.secondary = TextStyle(foreground: .rgb(221, 208, 180))
            theme.muted = TextStyle(foreground: .rgb(133, 146, 137))
            theme.accent = TextStyle(foreground: .rgb(167, 192, 128))
            theme.info = TextStyle(foreground: .rgb(127, 187, 179), background: .rgb(54, 62, 68), bold: true)
            theme.highlighted = TextStyle(foreground: .rgb(214, 153, 182), background: .rgb(58, 66, 72), bold: true)
            theme.success = TextStyle(foreground: .rgb(131, 192, 146))
            theme.warning = TextStyle(foreground: .rgb(219, 188, 127))
            theme.error = TextStyle(foreground: .rgb(230, 126, 128))
            theme.border = TextStyle(foreground: .rgb(101, 109, 115))
            theme.surface = TextStyle(foreground: theme.normal.foreground, background: .rgb(46, 54, 60))
            theme.field = TextStyle(foreground: theme.normal.foreground, background: .rgb(50, 60, 65))
            theme.selection = TextStyle(foreground: .rgb(231, 218, 190), background: .rgb(61, 69, 75))
            theme.syntaxKeyword = TextStyle(foreground: .rgb(230, 126, 128), bold: true)
            theme.syntaxType = TextStyle(foreground: .rgb(131, 192, 146))
            theme.syntaxFunction = TextStyle(foreground: .rgb(167, 192, 128))
            theme.syntaxProperty = TextStyle(foreground: .rgb(127, 187, 179))
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
