import Foundation

/// Which style of box‑drawing characters to use for borders.
public enum BorderStyle {
    /// Unicode box‑drawing (─│┌┐└┘)
    case unicode
    /// ASCII fallback (+, -, |)
    case ascii
}
