import TerminalUIEngine
@testable import TerminalUIRendering
@testable import TerminalUIRuntime
import Testing

@MainActor
struct TargetedRepaintTests {
    @Test func `scrolling preserves unrelated widgets without drawing them again`() throws {
        let probe = RepaintProbe()
        let root = Element.panel(title: "Workspace", content: .row([
            .scrollView(id: "scroll", content: .paragraph("界 first\nsecond\nthird\nfourth\nlast"))
                .width(.fixed(12)),
            .custom(RepaintWidget(probe: probe)).width(.fill()),
        ])).background(.blue)
        let app = RepaintApplication(root)
        let host = TerminalHost()
        let reference = UIEngine()
        let size = TerminalSize(columns: 28, rows: 5)
        let initial = try #require(host.renderIfNeeded(app, size: size))
        #expect(initial == reference.renderGrid(root, width: size.columns, height: size.rows))
        for key in [KeyEvent.up, .down, .pageDown, .end, .down, .pageUp, .home] {
            host.handleInput(key, application: app)
            _ = reference.handle(key, in: root)
            let draws = probe.draws
            let actual = try #require(host.renderIfNeeded(app, size: size))
            #expect(probe.draws == draws)
            #expect(actual == reference.renderGrid(root, width: size.columns, height: size.rows))
        }
        #expect(app.viewCalls == 1)
        #expect(app.actions.isEmpty)
    }

    @Test func `targeted frames match full frames through nesting overlays styles and clipping`() {
        let text = Element.paragraph([
            TextSpan("界 wide\nshort\n\n🙂 emoji\nlast long row", role: .warning),
        ])
        let scroll = Element.scrollView(id: "scroll", content: text).height(.fixed(3))
        let views: [Element] = [
            .column([.text("header"), scroll, .text("footer")]).background(.blue),
            .row([.text("left").width(.fixed(6)), scroll.width(.fill())]).padding(.all(1)),
            .panel(title: "Panel", content: scroll.padding(.all(1))).background(.red),
            .scrollView(id: "outer", content: .column([
                .text("header"), scroll, .paragraph("tail\nmore\nlast"),
            ])).height(.fixed(4)),
            .text("base content").overlay(.dialog(id: "modal", title: "Dialog", content: scroll)),
            .text("base content").overlay(.column([.text("overlay header"), scroll])),
            .panel(title: "Dividers", content: .scrollView(id: "scroll", content: .column([
                .divider(), .text("one"), .divider(), .text("two"), .divider(),
            ])).height(.fixed(3))),
            .column([.text("header"), scroll, .text("footer")]).height(.fixed(2)),
        ]
        for root in views {
            let engine = UIEngine()
            let reference = UIEngine()
            #expect(engine.focus("scroll", in: root))
            #expect(reference.focus("scroll", in: root))
            #expect(engine.renderGrid(root, width: 18, height: 8) == reference.renderGrid(root, width: 18, height: 8))
            for key in [KeyEvent.down, .pageDown, .end, .down, .pageUp, .home, .up] {
                #expect(engine.handleEvent(key, in: root) == .repaint)
                _ = reference.handleEvent(key, in: root)
                #expect(engine.repaintGrid(width: 18, height: 8) == reference.renderGrid(root, width: 18, height: 8))
            }
        }
    }

    @Test func `batched scrolling resize and invalidation preserve complete frames`() {
        let probe = RepaintProbe()
        let app = RepaintApplication(.column([
            .scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour\nfive")).height(.fixed(2)),
            .custom(RepaintWidget(probe: probe)),
        ]))
        let host = TerminalHost()
        let reference = UIEngine()
        var size = TerminalSize(columns: 16, rows: 4)
        _ = host.renderIfNeeded(app, size: size)
        _ = reference.renderGrid(app.root, width: size.columns, height: size.rows)
        for key in [KeyEvent.down, .down, .up] {
            host.handleInput(key, application: app)
            _ = reference.handle(key, in: app.root)
        }
        #expect(host.renderIfNeeded(app, size: size) == reference.renderGrid(app.root, width: size.columns, height: size.rows))
        // Changing dimensions requires a complete repaint even without application invalidation.
        host.handleInput(.down, application: app)
        _ = reference.handle(.down, in: app.root)
        size = TerminalSize(columns: 20, rows: 5)
        let draws = probe.draws
        #expect(host.renderIfNeeded(app, size: size) == reference.renderGrid(app.root, width: size.columns, height: size.rows))
        #expect(probe.draws == draws + 2)
        app.root = .column([
            .scrollView(id: "scroll", content: .paragraph("changed\nlast")).height(.fixed(2)),
            .text("updated sibling"),
        ])
        host.invalidate()
        host.handleInput(.home, application: app)
        _ = reference.handle(.home, in: app.root)
        #expect(host.renderIfNeeded(app, size: size) == reference.renderGrid(app.root, width: size.columns, height: size.rows))
        #expect(app.viewCalls == 2)
        #expect(app.actions.isEmpty)
    }

    @Test(arguments: ["theme", "visibility", "reset", "focus"])
    func `engine state changes discard the previous frame`(_ change: String) {
        let probe = RepaintProbe()
        let root = Element.column([
            .scrollView(id: "scroll", content: .paragraph("one\ntwo\nthree\nfour").id("tail")).height(.fixed(2)),
            .custom(RepaintWidget(probe: probe)),
        ])
        let engine = UIEngine()
        let reference = UIEngine()
        _ = engine.renderGrid(root, width: 20, height: 4)
        _ = reference.renderGrid(root, width: 20, height: 4)
        for value in [engine, reference] {
            _ = value.handleEvent(.down, in: root)
            switch change {
            case "theme": value.theme = .dark
            case "visibility": value.keepVisible("tail")
            case "reset": value.resetState(for: "scroll")
            default: #expect(value.focus("scroll", in: root))
            }
        }
        let draws = probe.draws
        let actual = engine.repaintGrid(width: 20, height: 4)
        #expect(probe.draws == draws + 1)
        #expect(actual == reference.renderGrid(root, width: 20, height: 4))
    }
}

@MainActor
private final class RepaintApplication: TerminalApplication {
    var root: Element
    var viewCalls = 0
    var actions: [UIAction] = []

    init(_ root: Element) {
        self.root = root
    }

    func view() -> Element {
        viewCalls += 1; return root
    }

    func handle(_ action: UIAction) {
        actions.append(action)
    }
}

private final class RepaintProbe {
    var draws = 0
}

private struct RepaintWidget: CustomWidget {
    let id: String? = nil
    let probe: RepaintProbe

    func measure(width: Int) -> WidgetSize {
        WidgetSize(width: width, height: 1)
    }

    func draw(in canvas: inout Canvas, focused _: Bool) {
        probe.draws += 1
        canvas.write("unchanged 界", x: 0, y: 0)
    }
}
