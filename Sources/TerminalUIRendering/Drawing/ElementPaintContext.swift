import TerminalUICore
import TerminalUILayout

/// Immutable inputs shared by built-in painters for one assigned content rectangle.
struct ElementPaintContext {
    let element: Element
    let theme: Theme
    let inherited: StyleOverride
    let active: Bool
    let focusedID: String?
    let originX: Int
    let originY: Int
    let contentWidth: Int
    let contentHeight: Int
    let bounds: MouseRect
    let manuallyScrolled: Set<String>

    func resolved(_ role: TextRole, state: TextRole? = nil) -> TextStyle {
        let descendants = inherited.merging(element.styleOverride)
        var style = inherited.applying(to: theme[role])
        if let state { style = theme[state] }
        if !active { style = theme.disabled }
        if style.background == .default { style.background = descendants.background ?? theme.normal.background }
        return element.styleOverride.applying(to: style)
    }

    func write(_ text: String, row: Int, column: Int = 0, style: TextStyle? = nil, canvas: inout Canvas) {
        guard row >= 0, row < contentHeight, column >= 0, column < contentWidth else { return }
        canvas.write(text, x: originX + column, y: originY + row,
                     style: style ?? resolved(element.textRole), clipWidth: contentWidth - column)
    }
}
