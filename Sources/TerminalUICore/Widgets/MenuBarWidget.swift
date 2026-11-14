/// Horizontal actions with application-owned focus and current-destination state.
struct MenuBarWidget: CustomWidget {
    let id: String?
    let items: [MenuItem]
    let selection: String?
    let focusedItem: String?
    let compact: Bool
    var isFocusable: Bool { !items.isEmpty }

    private var focusIndex: Int {
        items.firstIndex { $0.id == focusedItem } ?? items.firstIndex { $0.id == selection } ?? 0
    }

    private func label(_ item: MenuItem) -> String {
        (item.shortcut.map { String($0).uppercased() + (compact ? "" : " ") } ?? "") + String(item.title.prefix(4096))
    }

    private func width(_ text: String) -> Int {
        text.prefix(4096).reduce(0) { min(4096, $0 + max(1, CellWidth.width(of: $1))) }
    }

    func measure(context: WidgetMeasureContext) -> WidgetSize {
        let labels = items.map { label($0) }.joined(separator: " ")
        let markers = items.contains { $0.id == selection } ? 2 : 1
        return WidgetSize(width: min(context.width, width(labels) + markers), height: 1)
    }

    private func itemLayout(width available: Int, focused: Bool) -> [(index: Int, column: Int, width: Int)] {
        let labels = items.enumerated().map { index, item in
            (focused && index == focusIndex ? ">" : "") + (item.id == selection ? "*" : "") + label(item)
        }
        let widths = labels.map { width($0) + 1 }
        let target = focused ? focusIndex : (items.firstIndex { $0.id == selection } ?? 0)
        var start = 0
        var used = 0
        if !items.isEmpty {
            for index in 0...target {
                used += widths[index]
                while used - 1 > available && start < index {
                    used -= widths[start]
                    start += 1
                }
            }
        }
        var column = 0
        return (start..<items.count).compactMap { index in
            defer { column += widths[index] }
            guard column < available else { return nil }
            return (index, column, min(widths[index] - 1, available - column))
        }
    }

    func mouseTarget(at mouse: MouseEvent, context: WidgetMouseContext) -> String? {
        guard mouse.row == 0, let hit = itemLayout(width: context.size.width, focused: context.focused).first(where: {
            mouse.column >= $0.column && mouse.column < $0.column + $0.width
        }) else { return nil }
        return items[hit.index].id
    }

    func respond(to mouse: MouseEvent, context: WidgetMouseContext) -> WidgetResponse {
        guard let id, let target = mouseTarget(at: mouse, context: context), let item = items.first(where: { $0.id == target })
        else { return .unhandled }
        switch mouse.kind {
        case .press: return .action(.selectionChanged(id, item.id))
        case .release: return item.unavailableReason == nil ? .action(.activated(item.id)) : .consumed
        default: return .unhandled
        }
    }

    func draw(in canvas: inout Canvas, context: WidgetDrawContext) {
        for entry in itemLayout(width: canvas.width, focused: context.focused) {
            let index = entry.index, column = entry.column
            let style: TextStyle
            if !context.enabled || items[index].unavailableReason != nil { style = context.theme.disabled }
            else if context.focused && index == focusIndex { style = context.theme.focused }
            else if items[index].id == selection { style = context.theme.selection }
            else { style = context.style }
            var labelStyle = style
            if labelStyle.background == .default { labelStyle.background = context.style.background }
            let prefix = (context.focused && index == focusIndex ? ">" : "") + (items[index].id == selection ? "*" : "")
            canvas.write(prefix, x: column, y: 0, style: labelStyle)
            var shortcutStyle = labelStyle
            if context.enabled && items[index].unavailableReason == nil {
                shortcutStyle.foreground = context.theme.muted.foreground
                shortcutStyle.bold = false
            }
            let shortcut = items[index].shortcut.map { String($0).uppercased() + (compact ? "" : " ") } ?? ""
            canvas.write(shortcut, x: column + width(prefix), y: 0, style: shortcutStyle)
            canvas.write(String(items[index].title.prefix(4096)), x: column + width(prefix + shortcut), y: 0, style: labelStyle)
        }
    }

    func respond(to key: KeyEvent, context: WidgetEventContext) -> WidgetResponse {
        guard let id, !items.isEmpty else { return .unhandled }
        let next: Int
        switch key {
        case .left: next = max(0, focusIndex - 1)
        case .right: next = min(items.count - 1, focusIndex + 1)
        case .home: next = 0
        case .end: next = items.count - 1
        case .enter, .character(" "):
            guard items[focusIndex].unavailableReason == nil else { return .consumed }
            return .action(.activated(items[focusIndex].id))
        case .character(let character):
            guard let item = items.first(where: { $0.shortcut.map { String($0).lowercased() } == String(character).lowercased() })
            else { return .unhandled }
            return .action(.activated(item.id))
        default: return .unhandled
        }
        return .action(.selectionChanged(id, items[next].id))
    }
}
