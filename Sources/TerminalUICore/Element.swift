/// A value describing a terminal interface. Rebuild it from application state after actions.
public struct Element {
    package indirect enum Kind {
        case text(String), paragraph(String), styledParagraph([TextSpan]), column(Int, [Element]), row(Int, [Element]), panel(String, Element)
        case button(String, String), field(String, String, String, Bool)
        case list(String, [ListRow], String?), table(String, [TableColumn], [TableRow], String?, Bool), dialog(String, String, Element), overlay(Element, Element)
        case scroll(String, Element), custom(any CustomWidget), spacer, divider
    }
    package let kind: Kind
    package var widthRule: LayoutSize = .content
    package var heightRule: LayoutSize = .content
    package var insets = Insets()
    package var textRole: TextRole = .normal
    package var styleOverride = StyleOverride()
    package var alignment: Alignment?
    package var visibilityID: String?
    package var isVisible = true
    package var isEnabled = true
    package var submitID: String?
    package var menuResultsID: String?
    package var listLineLimit = 1
    package var listRowSpacing = 0
    package var followsEnd = false
    package var keyActions: [(key: KeyEvent, actionID: String)] = []
    package var menuShortcutItems: [MenuItem] = []

    public static func text(_ value: String) -> Self { .init(kind: .text(value)) }
    public static func paragraph(_ value: String) -> Self { .init(kind: .paragraph(value)) }
    public static func paragraph(_ spans: [TextSpan]) -> Self { .init(kind: .styledParagraph(spans)) }
    public static func statusBar(_ value: String) -> Self { .text(value).role(.secondary) }
    public static func keyHints(_ value: String) -> Self { .text(value).role(.secondary) }
    public static func column(spacing: Int = 0, _ children: [Self]) -> Self { .init(kind: .column(max(0, spacing), children)) }
    public static func row(spacing: Int = 0, _ children: [Self]) -> Self { .init(kind: .row(max(0, spacing), children)) }
    public static func panel(title: String, content: Self) -> Self { .init(kind: .panel(title, content)) }
    public static func button(_ title: String, id: String) -> Self { .init(kind: .button(title, id)) }
    /// Switch sections with Left/Right or Home/End; selection remains application-owned.
    public static func tabs(id: String, tabs: [Tab], selection: String?) -> Self {
        .custom(TabsWidget(id: id, tabs: tabs, selection: selection))
    }
    /// A passive, textual percentage. Values are clamped to 0...1; non-finite values display 0%.
    public static func progress(_ value: Double) -> Self {
        let fraction = value.isFinite ? min(1, max(0, value)) : 0
        return .text("\(Int((fraction * 100).rounded()))%")
    }
    public static func textField(id: String, value: String, placeholder: String = "") -> Self { .init(kind: .field(id, value, placeholder, false)) }
    public static func textEditor(id: String, value: String, placeholder: String = "") -> Self { .init(kind: .field(id, value, placeholder, true)) }
    /// Makes Enter activate the supplied action in this editor. Shift+Enter inserts a newline when reported by the terminal.
    public func onSubmit(_ id: String) -> Self { var copy = self; copy.submitID = id; return copy }
    /// Activates an action for this key when the control has focus. Paste remains a separate event.
    public func onKey(_ key: KeyEvent, activate id: String) -> Self {
        var copy = self
        copy.keyActions.append((key, id))
        return copy
    }
    /// Wrap titles within a bounded number of lines, with optional space between rows.
    public static func list(id: String, rows: [ListRow], selection: String?, lineLimit: Int = 1, rowSpacing: Int = 0) -> Self {
        var element = Self(kind: .list(id, rows, selection))
        element.listLineLimit = min(4096, max(1, lineLimit))
        element.listRowSpacing = min(4096, max(0, rowSpacing))
        return element
    }

    /// A table with a fixed header and application-owned row selection.
    /// Set `bordered` to draw an outline, column dividers and a header separator.
    public static func table(id: String, columns: [TableColumn], rows: [TableRow], selection: String?, bordered: Bool = false) -> Self {
        .init(kind: .table(id, columns, rows, selection, bordered))
    }
    /// When following the end, appended content stays visible until the user scrolls up.
    public static func scrollView(id: String, content: Self, followsEnd: Bool = false) -> Self {
        var element = Self(kind: .scroll(id, content))
        element.followsEnd = followsEnd
        return element
    }

    public static func dialog(id: String, title: String, content: Self) -> Self { .init(kind: .dialog(id, title, content)) }
    public static func custom(_ widget: any CustomWidget) -> Self { .init(kind: .custom(widget)) }
    public static func spacer() -> Self { .init(kind: .spacer, widthRule: .fill(), heightRule: .fill()) }
    public static func divider() -> Self { .init(kind: .divider) }
    public func overlay(_ element: Self?) -> Self { element.map { .init(kind: .overlay(self, $0)) } ?? self }
    public func width(_ rule: LayoutSize) -> Self { var copy = self; copy.widthRule = rule; return copy }
    public func height(_ rule: LayoutSize) -> Self { var copy = self; copy.heightRule = rule; return copy }
    public func padding(_ insets: Insets) -> Self { var copy = self; copy.insets = insets; return copy }
    /// Identifies content for a programmatic keep-visible request.
    public func id(_ value: String) -> Self { var copy = self; copy.visibilityID = value; return copy }
    /// Aligns text within its width or children across a stack.
    public func alignment(_ value: Alignment) -> Self { var copy = self; copy.alignment = value; return copy }
    public func role(_ value: TextRole) -> Self { var copy = self; copy.textRole = value; return copy }
    /// Overrides only specified properties; on containers these properties are inherited.
    public func style(_ value: StyleOverride) -> Self { var copy = self; copy.styleOverride = copy.styleOverride.merging(value); return copy }
    public func foreground(_ value: TextStyle.Color) -> Self { style(.init(foreground: value)) }
    public func background(_ value: TextStyle.Color) -> Self { style(.init(background: value)) }
    public func bold(_ value: Bool = true) -> Self { style(.init(bold: value)) }
    public func dim(_ value: Bool = true) -> Self { style(.init(dim: value)) }
    public func italic(_ value: Bool = true) -> Self { style(.init(italic: value)) }
    public func underline(_ value: Bool = true) -> Self { style(.init(underline: value)) }
    public func visible(_ value: Bool) -> Self { var copy = self; copy.isVisible = value; return copy }
    public func enabled(_ value: Bool) -> Self { var copy = self; copy.isEnabled = value; return copy }
}
