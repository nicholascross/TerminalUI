/// Single-cell border glyphs shared by panels, dialogs, tables and dividers.
public struct BorderCharacters: Sendable {
    package let topLeft: String
    package let topRight: String
    package let bottomLeft: String
    package let bottomRight: String
    package let horizontal: String
    package let vertical: String
    package let leftJoin: String
    package let rightJoin: String
    package let topJoin: String
    package let bottomJoin: String
    package let cross: String

    public static let square = Self(topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘",
                                    horizontal: "─", vertical: "│", leftJoin: "├", rightJoin: "┤",
                                    topJoin: "┬", bottomJoin: "┴", cross: "┼")
    public static let rounded = Self(topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯",
                                     horizontal: "─", vertical: "│", leftJoin: "├", rightJoin: "┤",
                                     topJoin: "┬", bottomJoin: "┴", cross: "┼")
    public static let ascii = Self(topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+",
                                   horizontal: "-", vertical: "|", leftJoin: "+", rightJoin: "+",
                                   topJoin: "+", bottomJoin: "+", cross: "+")
}
