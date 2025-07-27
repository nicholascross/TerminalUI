import Foundation

extension String {
    /// Returns a new string in which tab characters (`\t`) are replaced by spaces,
    /// aligning to tab stops of given width (default: 4 spaces).
    func replacingTabs(withTabWidth tabWidth: Int = 4) -> String {
        var result = ""
        var column = 0
        for char in self {
            if char == "\t" {
                let spaces = tabWidth - (column % tabWidth)
                result += String(repeating: " ", count: spaces)
                column += spaces
            } else {
                result.append(char)
                // Use terminalColumnWidth to account for wide characters
                column += char.terminalColumnWidth
            }
        }
        return result
    }
}
