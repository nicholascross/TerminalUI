import TerminalUICore

@MainActor
package protocol BuiltinView: PrimitiveView {
    var makeElement: () -> Element { get }
}

extension BuiltinView {
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = makeElement()
        element.compositionPath = path
        return [element]
    }
}

public struct Text: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(_ value: String) { self.makeElement = { .text(value) } }
}

public struct Paragraph: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(_ value: String) { self.makeElement = { .paragraph(value) } }
    public init(_ spans: [TextSpan]) { self.makeElement = { .paragraph(spans) } }
}

public struct Button: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(_ title: String, id: String? = nil) {
        self.makeElement = {
            if let id { return .button(title, id: id) }
            return .component(ViewDescriptor(value: AnonymousButton(title: title)))
        }
    }
}

/// Its mounted component supplies a stable, independent address for each anonymous button.
private struct AnonymousButton: TerminalView {
    let title: String
    var body: some TerminalView { Button(title, id: "@button") }
}

public struct TextField: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(id: String, value: String, placeholder: String = "") {
        self.makeElement = { .textField(id: id, value: value, placeholder: placeholder) }
    }
}

public struct TextEditor: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(id: String, value: String, placeholder: String = "") {
        self.makeElement = { .textEditor(id: id, value: value, placeholder: placeholder) }
    }
}

public struct List: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(id: String, rows: [ListRow], selection: String?, lineLimit: Int = 1, rowSpacing: Int = 0) {
        self.makeElement = { .list(id: id, rows: rows, selection: selection, lineLimit: lineLimit, rowSpacing: rowSpacing) }
    }
}

public struct Table: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(id: String, columns: [TableColumn], rows: [TableRow], selection: String?, bordered: Bool = false) {
        self.makeElement = { .table(id: id, columns: columns, rows: rows, selection: selection, bordered: bordered) }
    }
}

public struct Spacer: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init() { self.makeElement = { .spacer() } }
}

public struct Divider: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init() { self.makeElement = { .divider().layoutSizing(width: .flexible(), height: .fixed(1)) } }
}

public struct StatusBar: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(_ value: String) { self.makeElement = { .statusBar(value).layoutSizing(width: .flexible(), height: .fixed(1)) } }
}

public struct Progress: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(_ value: Double) { self.makeElement = { .progress(value) } }
}

public struct Tabs: BuiltinView {
    public typealias Body = Never
    package let makeElement: () -> Element
    public init(id: String, tabs: [Tab], selection: String?) {
        self.makeElement = { .tabs(id: id, tabs: tabs, selection: selection).layoutSizing(width: .flexible(), height: .fixed(1)) }
    }
}
