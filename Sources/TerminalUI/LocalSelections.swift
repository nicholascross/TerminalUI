import TerminalUICore

extension List {
    /// Keeps highlighted selection locally. Use a selection binding to share it with another view.
    public init(id: String, rows: [ListRow], initialSelection: String? = nil, lineLimit: Int = 1, rowSpacing: Int = 0) {
        makeElement = {
            .component(ViewDescriptor(value: LocalList(id: id, rows: rows, initialSelection: initialSelection,
                                                      lineLimit: lineLimit, rowSpacing: rowSpacing)))
        }
    }
}

@TerminalComponent
private struct LocalList: TerminalView {
    @State private var selection: String?
    let id: String
    let rows: [ListRow]
    let lineLimit: Int
    let rowSpacing: Int

    init(id: String, rows: [ListRow], initialSelection: String?, lineLimit: Int, rowSpacing: Int) {
        self.id = id
        self.rows = rows
        self.lineLimit = lineLimit
        self.rowSpacing = rowSpacing
        _selection = State(wrappedValue: initialSelection)
    }

    var body: some TerminalView {
        List(id: id, rows: rows, selection: $selection, lineLimit: lineLimit, rowSpacing: rowSpacing)
    }
}

extension Table {
    /// Keeps highlighted selection locally. Use a selection binding to share it with another view.
    public init(id: String, columns: [TableColumn], rows: [TableRow], initialSelection: String? = nil, bordered: Bool = false) {
        makeElement = {
            .component(ViewDescriptor(value: LocalTable(id: id, columns: columns, rows: rows,
                                                       initialSelection: initialSelection, bordered: bordered)))
        }
    }
}

@TerminalComponent
private struct LocalTable: TerminalView {
    @State private var selection: String?
    let id: String
    let columns: [TableColumn]
    let rows: [TableRow]
    let bordered: Bool

    init(id: String, columns: [TableColumn], rows: [TableRow], initialSelection: String?, bordered: Bool) {
        self.id = id
        self.columns = columns
        self.rows = rows
        self.bordered = bordered
        _selection = State(wrappedValue: initialSelection)
    }

    var body: some TerminalView {
        Table(id: id, columns: columns, rows: rows, selection: $selection, bordered: bordered)
    }
}
