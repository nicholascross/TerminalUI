import Foundation
import Darwin.C

extension Character {
    /// Ensure the locale is initialized once so `wcwidth` handles UTF-8 & East Asian widths.
    private static let _localeInitialized: Void = {
        setlocale(LC_CTYPE, "")
    }()

    /// The number of terminal columns this character occupies.
    var terminalColumnWidth: Int {
        // initialize locale on first use
        _ = Self._localeInitialized

        return Int(unicodeScalars.reduce(0) { sum, scalar in
            let width = wcwidth(Int32(scalar.value))
            return sum + max(Int(width), 0)
        })
    }
}
