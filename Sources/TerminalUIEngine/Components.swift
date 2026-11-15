import TerminalUICore

// Named factories avoid Swift parsing adjacent leading-dot expressions as one method chain.
// Every factory returns an ordinary Element, so existing modifiers and application actions apply.

public func Column(
    spacing: Int = 0, alignment: Alignment = .leading,
    @ElementBuilder content: () -> [Element]
) -> Element {
    .column(spacing: spacing, alignment: alignment, content: content)
}

public func Row(
    spacing: Int = 0, alignment: Alignment = .leading,
    @ElementBuilder content: () -> [Element]
) -> Element {
    .row(spacing: spacing, alignment: alignment, content: content)
}

public func Panel(_ title: String, content: () -> Element) -> Element { .panel(title: title, content: content()) }
public func ScrollView(id: String, followsEnd: Bool = false, content: () -> Element) -> Element {
    .scrollView(id: id, content: content(), followsEnd: followsEnd)
}
public func Dialog(id: String, title: String, content: () -> Element) -> Element {
    .dialog(id: id, title: title, content: content())
}
public func Text(_ value: String) -> Element { .text(value) }
public func Paragraph(_ value: String) -> Element { .paragraph(value) }
public func Paragraph(_ spans: [TextSpan]) -> Element { .paragraph(spans) }
public func Button(_ title: String, id: String) -> Element { .button(title, id: id) }
public func TextField(id: String, value: String, placeholder: String = "") -> Element {
    .textField(id: id, value: value, placeholder: placeholder)
}
public func TextEditor(id: String, value: String, placeholder: String = "") -> Element {
    .textEditor(id: id, value: value, placeholder: placeholder)
}
public func List(id: String, rows: [ListRow], selection: String?, lineLimit: Int = 1, rowSpacing: Int = 0) -> Element {
    .list(id: id, rows: rows, selection: selection, lineLimit: lineLimit, rowSpacing: rowSpacing)
}
public func Table(id: String, columns: [TableColumn], rows: [TableRow], selection: String?, bordered: Bool = false) -> Element {
    .table(id: id, columns: columns, rows: rows, selection: selection, bordered: bordered)
}
public func Spacer() -> Element { .spacer() }
public func Divider() -> Element { .divider().layoutSizing(width: .flexible(), height: .fixed(1)) }
public func StatusBar(_ value: String) -> Element { .statusBar(value).layoutSizing(width: .flexible(), height: .fixed(1)) }
public func Progress(_ value: Double) -> Element { .progress(value) }
public func Custom(_ widget: any CustomWidget) -> Element { .custom(widget) }
public func Tabs(id: String, tabs: [Tab], selection: String?) -> Element {
    .tabs(id: id, tabs: tabs, selection: selection).layoutSizing(width: .flexible(), height: .fixed(1))
}
public func MenuBar(
    id: String, items: [MenuItem], selection: String?, focusedItem: String? = nil,
    compact: Bool = false
) -> Element {
    .menuBar(id: id, items: items, selection: selection, focusedItem: focusedItem, compact: compact)
        .layoutSizing(width: .flexible(), height: .fixed(1))
}
public func Menu(
    id: String, title: String, items: [MenuItem], query: String,
    selection: String?, notice: String? = nil
) -> Element {
    .menu(id: id, title: title, items: items, query: query, selection: selection, notice: notice)
}
