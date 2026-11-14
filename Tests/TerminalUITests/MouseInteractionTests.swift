import TerminalUI
@testable import TerminalUIRendering
import Testing

struct MouseInteractionTests {
    @Test func `missing geometry cannot leave A stale press for A later release`() {
        let engine = UIEngine()
        let root = Element.button("Go", id: "go")
        #expect(engine.handleMouseEvent(.init(.press, column: 1, row: 0)).action == nil)
        _ = engine.render(root, width: 10, height: 1)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 0))
        // The direct engine API requires a render after focus/geometry-changing input.
        #expect(engine.handleMouseEvent(.init(.release, column: 1, row: 0)).action == nil)
        _ = engine.render(root, width: 10, height: 1)
        #expect(engine.handleMouseEvent(.init(.release, column: 1, row: 0)).action == nil)
    }

    @Test func `button click focuses and activates exactly once with matching release`() {
        let engine = UIEngine()
        let root = Element.column([.textField(id: "field", value: ""), .button("Go", id: "go")])
        _ = engine.render(root, width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.release, column: 2, row: 1)).action == nil)
        #expect(engine.handleMouseEvent(.init(.press, column: 2, row: 1)).action == nil)
        #expect(engine.focusedID == "go")
        _ = engine.render(root, width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.release, column: 2, row: 1)).action == .activated("go"))
        _ = engine.render(root, width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.release, column: 2, row: 1)).action == nil)
        #expect(engine.handleMouseEvent(.init(.press, column: 2, row: 1)).action == nil)
        _ = engine.render(root, width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.release, column: 2, row: 0)).action == nil)
    }

    @Test func `disabled hidden removed and resized targets cannot activate`() {
        let engine = UIEngine()
        let root = Element.column([
            .button("Hidden", id: "hidden").visible(false),
            .button("Disabled", id: "disabled").enabled(false),
            .button("Live", id: "live"),
        ])
        _ = engine.render(root, width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.press, column: 1, row: 0)).action == nil)
        #expect(engine.focusedID == "live")
        #expect(engine.handleMouseEvent(.init(.release, column: 1, row: 0)).action == nil)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        _ = engine.render(.text("gone"), width: 20, height: 4)
        #expect(engine.handleMouseEvent(.init(.release, column: 1, row: 1)).action == nil)
        _ = engine.render(root, width: 20, height: 4)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        _ = engine.render(root, width: 21, height: 4)
        #expect(engine.handleMouseEvent(.init(.release, column: 1, row: 1)).action == nil)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1, button: .secondary))
        #expect(engine.handleMouseEvent(.init(.release, column: 1, row: 1)).action == nil)
    }

    @Test func `field clicks place caret using horizontal clipping and wide characters`() {
        let engine = UIEngine()
        let root = Element.textField(id: "field", value: "ab界cd").width(.fixed(4))
        _ = engine.render(root, width: 4, height: 1)
        // The end caret makes the visible content start at cell 3 (the second cell of 界).
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 0))
        #expect(engine.handle(.character("!"), in: root) == .textChanged("field", "ab界!cd"))
        let wide = Element.textField(id: "wide", value: "界a").width(.fixed(10))
        _ = engine.render(wide, width: 10, height: 1)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 0))
        #expect(engine.handle(.character("!"), in: wide) == .textChanged("wide", "!界a"))
    }

    @Test func `editor click uses wrapped rows and clears selection`() {
        let engine = UIEngine()
        let root = Element.textEditor(id: "editor", value: "abcdef\n界x").height(.fixed(3))
        _ = engine.render(root, width: 4, height: 3)
        _ = engine.handle(.shiftLeft, in: root)
        _ = engine.render(root, width: 4, height: 3)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        #expect(engine.handle(.character("!"), in: root) == .textChanged("editor", "abcde!f\n界x"))
        let empty = Element.textField(id: "empty", value: "", placeholder: "Enter text")
        _ = engine.render(empty, width: 12, height: 1)
        _ = engine.handleMouseEvent(.init(.press, column: 10, row: 0))
        #expect(engine.handle(.character("x"), in: empty) == .textChanged("empty", "x"))
    }

    @Test func `panel border focuses its content and modal blocks underlying clicks`() {
        let engine = UIEngine()
        let root = Element.column([
            .textField(id: "outside", value: ""),
            .panel(title: "Window", content: .column([.textField(id: "inside", value: ""), .button("Go", id: "go")]))
                .height(.fixed(5)),
        ])
        _ = engine.render(root, width: 24, height: 6)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        #expect(engine.focusedID == "inside")
        _ = engine.render(root, width: 24, height: 6)
        _ = engine.handleMouseEvent(.init(.press, column: 2, row: 3))
        #expect(engine.focusedID == "go")
        _ = engine.render(root, width: 24, height: 6)
        _ = engine.handleMouseEvent(.init(.press, column: 1, row: 1))
        #expect(engine.focusedID == "go")
        let modal = root.overlay(.dialog(id: "modal", title: "Modal", content: .button("Close", id: "close"))
            .width(.fixed(12)).height(.fixed(3)))
        _ = engine.render(modal, width: 24, height: 6)
        _ = engine.handleMouseEvent(.init(.press, column: 15, row: 3))
        #expect(engine.focusedID == "close")
        #expect(engine.handleMouseEvent(.init(.release, column: 15, row: 3)).action == nil)
        _ = engine.render(root, width: 24, height: 6)
        #expect(engine.focusedID == "go")
    }

    @Test func `padding alignment and scroll clipping determine clickable cells`() {
        let engine = UIEngine()
        let root = Element.scrollView(id: "scroll", content: .column([
            .text("top").height(.fixed(3)),
            .button("Go", id: "go").width(.fixed(6)),
            .text("bottom").height(.fixed(3)),
        ]).alignment(.trailing)).padding(.init(top: 1, leading: 2, bottom: 1, trailing: 2))
        _ = engine.render(root, width: 16, height: 5)
        _ = engine.handleMouseEvent(.init(.press, column: 9, row: 4))
        #expect(engine.focusedID == "scroll")
        _ = engine.repaintGrid(width: 16, height: 5)
        #expect(engine.handleMouseEvent(.init(.scrollDown, column: 9, row: 2)) == .repaint)
        _ = engine.repaintGrid(width: 16, height: 5)
        _ = engine.handleMouseEvent(.init(.press, column: 9, row: 1))
        #expect(engine.focusedID == "go")
        _ = engine.render(root, width: 16, height: 5)
        #expect(engine.handleMouseEvent(.init(.release, column: 9, row: 1)).action == .activated("go"))
    }

    @Test func `nonmodal overlay background does not pass clicks through`() {
        let engine = UIEngine()
        let root = Element.button("Under", id: "under").overlay(.text("Cover").width(.fixed(5)))
        _ = engine.render(root, width: 20, height: 2)
        _ = engine.handleMouseEvent(.init(.press, column: 10, row: 0))
        #expect(engine.handleMouseEvent(.init(.release, column: 10, row: 0)).action == nil)
    }
}
