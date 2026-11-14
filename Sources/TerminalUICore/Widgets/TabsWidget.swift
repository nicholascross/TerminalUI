/// A controlled tab strip. The application applies selection actions to its next view.
struct TabsWidget: CustomWidget {
    let id: String?
    let tabs: [Tab]
    let selection: String?
    var isFocusable: Bool { !tabs.isEmpty }

    func measure(context: WidgetMeasureContext) -> WidgetSize {
        let width = tabs.reduce(0) { min(4096, $0 + min(4096, $1.title.prefix(4096).reduce(3) { $0 + max(1, CellWidth.width(of: $1)) })) }
        return WidgetSize(width: min(context.width, width), height: 1)
    }

    private func labels(focused: Bool) -> [String] {
        let focusID = tabs.first(where: { $0.id == selection })?.id ?? tabs.first?.id
        return tabs.map { (focused && $0.id == focusID ? ">" : " ") +
            ($0.id == selection ? "*" : " ") + $0.title + " " }
    }

    private func itemLayout(width available: Int, focused: Bool) -> [(index: Int, column: Int, width: Int)] {
        let widths = labels(focused: focused).map { $0.prefix(4096).reduce(0) { $0 + max(1, CellWidth.width(of: $1)) } }
        let selectedIndex = tabs.firstIndex { $0.id == selection } ?? 0
        var start = 0
        var used = 0
        if !tabs.isEmpty {
            for index in 0...selectedIndex {
                used += widths[index]
                while used > available && start < index {
                    used -= widths[start]
                    start += 1
                }
            }
        }
        var column = 0
        return (start..<tabs.count).compactMap { index in
            defer { column += widths[index] }
            guard column < available else { return nil }
            return (index, column, min(widths[index], available - column))
        }
    }

    func mouseTarget(at mouse: MouseEvent, context: WidgetMouseContext) -> String? {
        guard mouse.row == 0, let hit = itemLayout(width: context.size.width, focused: context.focused).first(where: {
            mouse.column >= $0.column && mouse.column < $0.column + $0.width
        }) else { return nil }
        return tabs[hit.index].id
    }

    func respond(to mouse: MouseEvent, context: WidgetMouseContext) -> WidgetResponse {
        guard mouse.kind == .press, let id, let target = mouseTarget(at: mouse, context: context) else { return .unhandled }
        return target == selection ? .consumed : .action(.selectionChanged(id, target))
    }

    func draw(in canvas: inout Canvas, context: WidgetDrawContext) {
        let labels = labels(focused: context.focused)
        for entry in itemLayout(width: canvas.width, focused: context.focused) {
            let style = !context.enabled ? context.theme.disabled :
                (tabs[entry.index].id == selection ? context.theme.selection : context.style)
            canvas.write(labels[entry.index], x: entry.column, y: 0, style: style)
        }
    }

    func respond(to key: KeyEvent, context: WidgetEventContext) -> WidgetResponse {
        guard let id, !tabs.isEmpty else { return .unhandled }
        let current = tabs.firstIndex { $0.id == selection }
        let next: Int
        switch key {
        case .left: next = max(0, (current ?? 0) - 1)
        case .right: next = min(tabs.count - 1, (current ?? -1) + 1)
        case .home: next = 0
        case .end: next = tabs.count - 1
        default: return .unhandled
        }
        return tabs[next].id == selection ? .consumed : .action(.selectionChanged(id, tabs[next].id))
    }
}
