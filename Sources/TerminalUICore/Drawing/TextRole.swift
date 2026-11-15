/// Semantic presentation roles for text and controls.
public enum TextRole: Sendable {
    case normal, secondary, muted, heading, accent, highlighted, info, success, warning, error
    case selection, focused, disabled, border, activeBorder, surface, field, cursor, dialog, action
    case syntaxKeyword, syntaxType, syntaxFunction, syntaxProperty
}
