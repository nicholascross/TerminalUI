import TerminalUIEngine
import Testing

struct PanelResizeTests {
    @Test(arguments: [false, true])
    func `row resizing shares space within both panes' bounds`(negotiated: Bool) throws {
        let engine = UIEngine()
        let panes: [Element] = [
            .panel(title: "Files", content: .paragraph("alpha beta gamma delta epsilon zeta"))
                .layoutSizing(width: .flexible(minimum: 10), height: .flexible())
                .resizable(id: "files", edge: .trailing, maximum: 42, preferredSize: 20),
            .panel(title: "Details", content: .text("Content"))
                .layoutSizing(width: .flexible(minimum: 14, maximum: 28), height: .flexible()),
            .panel(title: "Fixed", content: .text("Notes")).width(.fixed(12)),
        ]
        let row = negotiated
            ? Element.layout(StackLayout(axis: .horizontal, spacing: 1), children: panes)
            : Element.row(spacing: 1, panes)
        let view = Element.column([.text("Header"), row.height(.fill()), .statusBar("Footer")])
        let initial = engine.render(view, width: 60, height: 9)
        let rightEdge = try #require(Array(initial[1]).firstIndex(of: "┐"))
        #expect(rightEdge == 19)
        #expect(initial[3].contains("delta"))

        _ = engine.handleMouseEvent(MouseEvent(.press, column: rightEdge, row: 2))
        _ = engine.handleMouseEvent(MouseEvent(.drag, column: rightEdge + 2, row: 2))
        let live = engine.repaintGrid(width: 60, height: 9).lines
        #expect(Array(live[1]).firstIndex(of: "┐") == 21)
        _ = engine.handleMouseEvent(MouseEvent(.release, column: Int.max, row: 0))
        let wide = engine.repaintGrid(width: 60, height: 9).lines
        #expect(Array(wide[1]).firstIndex(of: "┐") == 31)
        #expect(Array(wide[1]).lastIndex(of: "┌") == 48)
        #expect(wide[2].contains("delta"))
        #expect(wide[8].hasPrefix("Footer"))

        let tight = engine.render(view, width: 28, height: 9)
        #expect(!tight.contains { $0.contains("┼") })
        let restored = engine.render(view, width: 60, height: 9)
        #expect(Array(restored[1]).firstIndex(of: "┐") == 31)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 31, row: 2))
        _ = engine.handleMouseEvent(MouseEvent(.release, column: Int.min, row: 2))
        let narrow = engine.repaintGrid(width: 60, height: 9).lines
        #expect(Array(narrow[1]).firstIndex(of: "┐") == 17)
        #expect(Array(narrow[1]).lastIndex(of: "┌") == 48)
    }

    @Test func `leading edge anchors the far border and Escape restores the starting layout`() throws {
        let engine = UIEngine()
        let view = Element.layout(StackLayout(axis: .vertical, spacing: 1), children: [
            .panel(title: "Top", content: .text("text"))
                .layoutSizing(width: .flexible(), height: .flexible(minimum: 6, maximum: 15)),
            .panel(title: "Bottom", content: .text("text"))
                .layoutSizing(width: .flexible(), height: .flexible(minimum: 4, maximum: 12))
                .resizable(id: "bottom", edge: .top, preferredSize: 6),
        ])
        let initial = engine.render(view, width: 22, height: 20)
        let top = try #require(initial.firstIndex { $0.contains("Bottom") })
        #expect(top == 14)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 10, row: top))
        _ = engine.handleMouseEvent(MouseEvent(.drag, column: 10, row: top - 3))
        let live = engine.repaintGrid(width: 22, height: 20).lines
        #expect(live[11].contains("Bottom"))
        #expect(live[19] == initial[19])
        #expect(engine.handleEvent(.escape, in: view) == .repaint)
        #expect(engine.repaintGrid(width: 22, height: 20).lines == initial)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 10, row: top))
        _ = engine.handleMouseEvent(MouseEvent(.release, column: 21, row: 0))
        let committed = engine.repaintGrid(width: 22, height: 20).lines
        #expect(committed[8].contains("Bottom"))
        #expect(committed[19] == initial[19])
    }

    @Test func `an overlay invalidates capture and selection still starts on panel text`() {
        let engine = UIEngine(textSelectionEnabled: true)
        let view = Element.row([
            .panel(title: "Files", content: .text("Select this").textSelection())
                .layoutSizing(width: .flexible(), height: .flexible())
                .resizable(id: "files", edge: .trailing, minimum: 12, preferredSize: 14),
            .panel(title: "Details", content: .text("text")).layoutSizing(width: .flexible(), height: .flexible()),
        ])
        let initial = engine.render(view, width: 38, height: 6)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 13, row: 2))
        _ = engine.handleMouseEvent(MouseEvent(.drag, column: 17, row: 2))
        _ = engine.repaintGrid(width: 38, height: 6)
        _ = engine.render(view.overlay(.dialog(id: "modal", title: "Modal", content: .text("Active"))), width: 38, height: 6)
        _ = engine.handleMouseEvent(MouseEvent(.release, column: 17, row: 2))
        #expect(engine.render(view, width: 38, height: 6) == initial)

        var copies: [String] = []
        for (kind, column) in [(MouseEvent.Kind.press, 1), (.drag, 6), (.release, 6)] {
            _ = engine.handleMouseEvent(MouseEvent(kind, column: column, row: 1), copySelection: { copies.append($0) })
        }
        #expect(copies == ["Select"])
    }

    @Test func `a panel can resize into spare space beside a fixed sibling`() {
        let engine = UIEngine()
        let view = Element.row(spacing: 1, [
            .panel(title: "Files", content: .text("files"))
                .padding(.init(leading: 2, trailing: 1))
                .resizable(id: "files", edge: .trailing, preferredSize: 12),
            .panel(title: "Fixed", content: .text("notes")).width(.fixed(8)),
        ])
        let initial = engine.render(view, width: 28, height: 4)
        #expect(Array(initial[0]).firstIndex(of: "┐") == 10)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 10, row: 1))
        _ = engine.handleMouseEvent(MouseEvent(.drag, column: 24, row: 1))
        let large = engine.repaintGrid(width: 28, height: 4).lines
        #expect(Array(large[0]).firstIndex(of: "┐") == 17)
        #expect(Array(large[0]).lastIndex(of: "┌") == 20)
        _ = engine.handleMouseEvent(MouseEvent(.release, column: 15, row: 1))
        #expect(Array(engine.repaintGrid(width: 28, height: 4).lines[0]).firstIndex(of: "┐") == 15)
    }

    @Test func `both panel preferences return when their stack has room`() {
        let engine = UIEngine()
        let view = Element.row([
            .panel(title: "Files", content: .text("files"))
                .layoutSizing(width: .flexible(minimum: 8))
                .resizable(id: "files", edge: .trailing, preferredSize: 12),
            .panel(title: "Details", content: .text("details"))
                .layoutSizing(width: .flexible(minimum: 8))
                .resizable(id: "details", edge: .leading, preferredSize: 14),
            .panel(title: "Fixed", content: .text("note")).width(.fixed(6)),
        ])
        _ = engine.render(view, width: 32, height: 5)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 11, row: 1))
        _ = engine.handleMouseEvent(MouseEvent(.release, column: 17, row: 1))
        let afterFiles = engine.repaintGrid(width: 32, height: 5).lines
        #expect(Array(afterFiles[0]).firstIndex(of: "┐") == 17)
        _ = engine.handleMouseEvent(MouseEvent(.press, column: 18, row: 1))
        _ = engine.handleMouseEvent(MouseEvent(.release, column: 10, row: 1))
        let afterDetails = engine.repaintGrid(width: 32, height: 5).lines
        #expect(Array(afterDetails[0]).firstIndex(of: "┐") == 9)
        #expect(Array(afterDetails[0]).lastIndex(of: "┌") == 26)

        let roomy = engine.render(view, width: 40, height: 5)
        #expect(Array(roomy[0]).firstIndex(of: "┐") == 17)
        #expect(Array(roomy[0]).lastIndex(of: "┌") == 34)
    }

    @Test func `restored preferences can use space beyond either drag edge`() {
        let view = Element.row([
            .panel(title: "Files", content: .text("files"))
                .layoutSizing(width: .flexible(minimum: 8))
                .resizable(id: "files", edge: .trailing, preferredSize: 16),
            .panel(title: "Details", content: .text("details"))
                .layoutSizing(width: .flexible(minimum: 8))
                .resizable(id: "details", edge: .leading, preferredSize: 16),
            .panel(title: "Notes", content: .text("note")).layoutSizing(width: .flexible()),
        ])
        let frame = UIEngine().render(view, width: 80, height: 5)
        #expect(Array(frame[0]).firstIndex(of: "┐") == 15)
        #expect(Array(frame[0]).lastIndex(of: "┌") == 32)
    }
}
