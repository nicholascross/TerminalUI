package extension Element {
    var children: [Element] {
        switch kind {
        case let .column(_, children), let .row(_, children), let .layout(_, children): children
        case let .boundary(_, child), let .panel(_, child), let .dialog(_, _, child), let .scroll(_, child): [child]
        case let .overlay(base, top): [base, top]
        default: []
        }
    }

    var controlID: String? {
        switch kind {
        case let .button(_, id), let .field(id, _, _, _), let .list(id, _, _), let .table(id, _, _, _, _), let .scroll(id, _): id
        case let .custom(widget): widget.id
        default: nil
        }
    }

    var stateKey: String? {
        if let panelResize { return panelResize.stateKey }
        switch kind {
        case let .field(id, _, _, multiline): return (multiline ? "editor:" : "field:") + id
        case let .list(id, _, _): return "list:" + id
        case let .table(id, _, _, _, _): return "table:" + id
        case let .scroll(id, _): return "scroll:" + id
        default: return nil
        }
    }
}
