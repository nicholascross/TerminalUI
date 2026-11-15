import TerminalUIEngine
import Testing

struct ListRowAvailabilityTests {
    @Test func disabledRowsRemainSelectableButCannotSubmit() {
        let engine = UIEngine()
        let rows = [ListRow(id: "open", title: "Open"), ListRow(id: "locked", title: "Locked", isEnabled: false)]
        let available = Element.list(id: "menu", rows: rows, selection: "open").onSubmit("go")
        #expect(engine.handle(.enter, in: available) == .activated("go"))
        #expect(engine.handle(.down, in: available) == .selectionChanged("menu", "locked"))
        let disabled = Element.list(id: "menu", rows: rows, selection: "locked").onSubmit("go")
        #expect(engine.handle(.enter, in: disabled) == nil)
        #expect(engine.handle(.up, in: disabled) == .selectionChanged("menu", "open"))
        let fallback = Element.list(id: "menu", rows: Array(rows.reversed()), selection: nil).onSubmit("go")
        #expect(engine.handle(.enter, in: fallback) == nil)
        #expect(engine.handle(.end, in: fallback) == .selectionChanged("menu", "open"))
    }

    @Test(arguments: ["open", "locked"])
    func disabledLabelAndStyleRemainVisibleWhenSelectedAndClipped(selection: String) {
        let engine = UIEngine()
        let rows = [ListRow(id: "open", title: "Open"), ListRow(id: "locked", title: "A long unavailable destination", isEnabled: false)]
        let view = Element.list(id: "menu", rows: rows, selection: selection)
        let grid = engine.renderGrid(view, width: 20, height: 2)
        #expect(grid.lines[1].contains("[disabled]"))
        #expect(grid[2, 1]?.style == engine.theme.disabled)
        #expect(grid[2, 0]?.style == (selection == "open" ? engine.theme.selection : engine.theme.normal))
        #expect(grid.lines[selection == "open" ? 0 : 1].hasPrefix(">"))
    }

    @Test func disabledLabelIsIncludedInContentWidth() {
        let view = Element.row([
            .list(id: "menu", rows: [ListRow(id: "locked", title: "No", isEnabled: false)], selection: "locked"),
            .text("Next")
        ])
        let screen = UIEngine().render(view, width: 24, height: 1).joined()
        #expect(screen.contains("[disabled] NoNext"))
    }
}
