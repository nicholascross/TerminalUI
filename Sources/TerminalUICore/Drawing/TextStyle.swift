/// Terminal-independent cell appearance.
public struct TextStyle: Equatable, Sendable {
    public enum Color: Equatable, Sendable {
        case `default`, black, red, green, yellow, blue, magenta, cyan, white
        case brightBlack, brightRed, brightGreen, brightYellow, brightBlue, brightMagenta, brightCyan, brightWhite
        case indexed(UInt8), rgb(UInt8, UInt8, UInt8)
    }

    public var foreground: Color
    public var background: Color
    public var bold: Bool
    public var dim: Bool
    public var italic: Bool
    public var underline: Bool
    public var reversed: Bool

    public init(foreground: Color = .default, background: Color = .default,
                bold: Bool = false, dim: Bool = false, italic: Bool = false,
                underline: Bool = false, reversed: Bool = false) {
        self.foreground = foreground; self.background = background
        self.bold = bold; self.dim = dim; self.italic = italic
        self.underline = underline; self.reversed = reversed
    }

    func dimmedForBackdrop(faintEnabled: Bool) -> Self {
        var style = self
        let ink = reversed ? background : foreground
        let paper = reversed ? foreground : background
        if case let .rgb(red, green, blue) = ink, case let .rgb(baseRed, baseGreen, baseBlue) = paper {
            func midpoint(_ first: UInt8, _ second: UInt8) -> UInt8 {
                UInt8((UInt16(first) + UInt16(second)) / 2)
            }
            let blended = Color.rgb(midpoint(red, baseRed), midpoint(green, baseGreen), midpoint(blue, baseBlue))
            if reversed { style.background = blended } else { style.foreground = blended }
        } else if faintEnabled {
            style.bold = false
            style.dim = true
        }
        return style
    }
}
