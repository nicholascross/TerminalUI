import TerminalUICore

/// Converts semantic cell styles to terminal attributes for one output capability.
struct ANSIStyleEncoder {
    let capability: ColorCapability
    let extendedAttributes: Bool

    func encode(_ style: TextStyle) -> String {
        var codes = ["0"]
        if style.bold { codes.append("1") }
        if style.dim, extendedAttributes { codes.append("2") }
        if style.italic, extendedAttributes { codes.append("3") }
        if style.underline { codes.append("4") }
        if style.reversed { codes.append("7") }
        codes += colorCodes(style.foreground, background: false)
        codes += colorCodes(style.background, background: true)
        return "\u{1B}[" + codes.joined(separator: ";") + "m"
    }

    private func colorCodes(_ color: TextStyle.Color, background: Bool) -> [String] {
        guard capability != .none else { return [] }
        let index: Int
        switch color {
        case .default: return []
        case .black: index = 0
        case .red: index = 1
        case .green: index = 2
        case .yellow: index = 3
        case .blue: index = 4
        case .magenta: index = 5
        case .cyan: index = 6
        case .white: index = 7
        case .brightBlack: index = 8
        case .brightRed: index = 9
        case .brightGreen: index = 10
        case .brightYellow: index = 11
        case .brightBlue: index = 12
        case .brightMagenta: index = 13
        case .brightCyan: index = 14
        case .brightWhite: index = 15
        case let .indexed(value): index = Int(value)
        case let .rgb(red, green, blue):
            if capability == .trueColor {
                return [background ? "48" : "38", "2", String(red), String(green), String(blue)]
            }
            index = nearest(red: Int(red), green: Int(green), blue: Int(blue), limit: capability == .ansi16 ? 16 : 256)
        }
        let mapped: Int
        if capability == .ansi16, index >= 16 {
            let rgb = palette(index)
            mapped = nearest(red: rgb.0, green: rgb.1, blue: rgb.2, limit: 16)
        } else { mapped = index }
        if mapped < 16 {
            return [String((background ? 40 : 30) + (mapped % 8) + (mapped >= 8 ? 60 : 0))]
        }
        return [background ? "48" : "38", "5", String(mapped)]
    }

    private func palette(_ index: Int) -> (Int, Int, Int) {
        let basic = [(0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128), (128, 0, 128), (0, 128, 128), (192, 192, 192),
                     (128, 128, 128), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]
        if index < 16 { return basic[index] }
        if index >= 232 { let value = 8 + (index - 232) * 10; return (value, value, value) }
        let value = index - 16
        let levels = [0, 95, 135, 175, 215, 255]
        return (levels[value / 36], levels[(value / 6) % 6], levels[value % 6])
    }

    private func nearest(red: Int, green: Int, blue: Int, limit: Int) -> Int {
        (0 ..< limit).min { first, second in
            func distance(_ index: Int) -> Int {
                let color = palette(index)
                return (red - color.0) * (red - color.0) + (green - color.1) * (green - color.1)
                    + (blue - color.2) * (blue - color.2)
            }
            return distance(first) < distance(second)
        } ?? 0
    }
}
