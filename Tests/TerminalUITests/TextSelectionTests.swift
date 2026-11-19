import TerminalUIEngine
import Testing

struct TextSelectionTests {
    @Test(arguments: [false, true])
    func `wrapped source is highlighted and copied through a panel border`(styled: Bool) {
        let theme = Theme()
        let engine = UIEngine(theme: theme, textSelectionEnabled: true)
        let text = styled
            ? Element.paragraph([TextSpan("ab cd", role: .syntaxKeyword), TextSpan(" ef\n\t界")])
            : Element.paragraph("ab cd ef\n\t界")
        let root = Element.panel(title: "Code", content: text.textSelection())
        let original = engine.renderGrid(root, width: 8, height: 5)
        #expect(original[5, 3]?.grapheme == "界")
        #expect(original[6, 3]?.width == 0)
        var copies: [String] = []
        let press = MouseEvent(.press, column: 2, row: 1)
        let drag = MouseEvent(.drag, column: 7, row: 3)
        let release = MouseEvent(.release, column: 7, row: 3)

        #expect(engine.handleMouseEvent(press) == .repaint)
        #expect(engine.handleMouseEvent(drag) { copies.append($0) } == .repaint)
        #expect(copies.isEmpty)
        let paints = engine.metrics.paints
        let highlighted = engine.repaintGrid(width: 8, height: 5)
        #expect(engine.metrics.paints == paints)
        #expect(highlighted.lines == original.lines)
        #expect(highlighted[1, 1] == original[1, 1])
        #expect(highlighted[2, 1]?.style == theme.selection)
        #expect(highlighted[5, 3]?.style == theme.selection)
        #expect(highlighted[6, 3]?.style == theme.selection)
        #expect(highlighted[7, 3] == original[7, 3])
        _ = engine.handleMouseEvent(release) { copies.append($0) }
        _ = engine.handleMouseEvent(release) { copies.append($0) }
        #expect(copies == ["b cd ef\n\t界"])

        _ = engine.handleMouseEvent(.init(.press, column: 6, row: 3))
        _ = engine.handleMouseEvent(.init(.release, column: 2, row: 1)) { copies.append($0) }
        #expect(copies == ["b cd ef\n\t界", "b cd ef\n\t界"])
    }

    @Test func `only opted in visible content starts selection`() {
        let engine = UIEngine(textSelectionEnabled: true)
        let root = Element.column([
            .text("Title"),
            .text("abcde").textSelection().width(.fixed(4)),
            .text("Under").textSelection().overlay(.text("Top")),
            .button("Run", id: "run"),
        ])
        let frame = engine.renderGrid(root, width: 10, height: 4)
        #expect(frame.lines[1].hasPrefix("abc…"))
        var copies: [String] = []
        for event in [
            MouseEvent(.press, column: 0, row: 0),
            MouseEvent(.press, column: 3, row: 1),
            MouseEvent(.press, column: 0, row: 2),
        ] {
            _ = engine.handleMouseEvent(event)
            _ = engine.handleMouseEvent(.init(.drag, column: 1, row: 1))
            _ = engine.handleMouseEvent(.init(.release, column: 1, row: 1)) { copies.append($0) }
            _ = engine.repaintGrid(width: 10, height: 4)
        }
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        _ = engine.handleMouseEvent(.init(.release, column: 1, row: 1)) { copies.append($0) }
        #expect(copies.isEmpty)

        _ = engine.handleMouseEvent(.init(.press, column: 2, row: 3))
        let pressedFrame = engine.repaintGrid(width: 10, height: 4)
        #expect(pressedFrame.lines[3].contains("[Run]"))
        #expect(engine.handleMouseEvent(.init(.release, column: 2, row: 3)).action == .activated("run"))
    }

    @Test func `scrolling remaps visible source and resize cancels the drag`() {
        let engine = UIEngine(textSelectionEnabled: true)
        let root = Element.scrollView(id: "source", content: .paragraph("one\ntwo\nthree\nfour\nfive\nsix").textSelection())
        _ = engine.renderGrid(root, width: 10, height: 2)
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 0, row: 0))
        engine.prepareMouseInput(width: 10, height: 2)
        var copies: [String] = []
        _ = engine.handleMouseEvent(.init(.press, column: 0, row: 0))
        _ = engine.handleMouseEvent(.init(.release, column: 3, row: 1)) { copies.append($0) }
        #expect(copies == ["four\nfive"])
        _ = engine.handleMouseEvent(.init(.press, column: 0, row: 0))
        engine.prepareMouseInput(width: 8, height: 2)
        _ = engine.handleMouseEvent(.init(.release, column: 3, row: 1)) { copies.append($0) }
        #expect(copies == ["four\nfive"])
    }

    @Test func `wheel extends an active drag when the pointer stays in the same cell`() {
        let engine = UIEngine(textSelectionEnabled: true)
        let text = Element.paragraph("zero\none\ntwo\nthree\nfour\nfive\nsix").textSelection()
        let root = Element.scrollView(id: "source", content: text)
        _ = engine.renderGrid(root, width: 10, height: 2)
        var copies: [String] = []
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 1, row: 1))
        let frame = engine.repaintGrid(width: 10, height: 2)
        #expect(frame.lines[0].hasPrefix("three"))
        #expect(frame[0, 0]?.style == engine.theme.selection)
        #expect(frame[1, 1]?.style == engine.theme.selection)
        #expect(frame[2, 1]?.style != engine.theme.selection)
        #expect(copies.isEmpty)
        #expect(!engine.canAutoscrollSelection)
        _ = engine.handleMouseEvent(.init(.release, column: 1, row: 1)) { copies.append($0) }
        #expect(copies == ["ne\ntwo\nthree\nfo"])
        #expect(!engine.canAutoscrollSelection)
    }

    @Test func `edge scrolling crosses blank lines and stops at the end of the selected text`() {
        let text = "one\ntwo\n\n\n\n\nlast"
        let engine = UIEngine(textSelectionEnabled: true)
        let root = Element.scrollView(id: "source", content: .column([
            .paragraph(text).textSelection(),
            .paragraph("Other content\nBelow the selection"),
        ]))
        _ = engine.renderGrid(root, width: 20, height: 2)
        let start = MouseEvent(.press, column: 0, row: 0)
        let end = MouseEvent(.drag, column: 3, row: 1)
        _ = engine.handleMouseEvent(start)
        #expect(!engine.canAutoscrollSelection)
        _ = engine.handleMouseEvent(end)
        for _ in 0 ..< 5 {
            #expect(engine.canAutoscrollSelection)
            #expect(engine.autoscrollSelection())
            _ = engine.repaintGrid(width: 20, height: 2)
        }
        #expect(!engine.canAutoscrollSelection)
        #expect(!engine.autoscrollSelection())
        var copies: [String] = []
        _ = engine.handleMouseEvent(.init(.release, column: end.column, row: end.row)) { copies.append($0) }
        #expect(copies == [text])

        _ = engine.handleMouseEvent(.init(.press, column: 3, row: 1))
        _ = engine.handleMouseEvent(.init(.drag, column: 0, row: 0))
        for _ in 0 ..< 5 {
            #expect(engine.autoscrollSelection())
            _ = engine.repaintGrid(width: 20, height: 2)
        }
        _ = engine.handleMouseEvent(.init(.release, column: 0, row: 0)) { copies.append($0) }
        #expect(copies == [text, text])
    }
}
