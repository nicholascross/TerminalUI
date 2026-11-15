import Foundation

/// The color depth accepted by the terminal. Attribute support is configured separately.
public enum ColorCapability: Sendable {
    case none, ansi16, indexed256, trueColor

    /// Conservative environment-based detection; callers may override it for multiplexers.
    public static func detect(environment: [String: String] = ProcessInfo.processInfo.environment,
                              interactive: Bool = true) -> Self {
        guard interactive, (environment["NO_COLOR"] ?? "").isEmpty,
              let term = environment["TERM"], !term.isEmpty, term != "dumb" else { return .none }
        let colorTerm = (environment["COLORTERM"] ?? "").lowercased()
        if colorTerm == "truecolor" || colorTerm == "24bit" { return .trueColor }
        if term.contains("256color") { return .indexed256 }
        return .ansi16
    }
}
