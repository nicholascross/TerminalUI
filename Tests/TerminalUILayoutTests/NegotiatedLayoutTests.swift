import Foundation
import TerminalUIEngine
import Testing

struct NegotiatedLayoutTests {
    private func rows(_ count: Int = 30) -> [ListRow] {
        (0..<count).map { ListRow(id: "\($0)", title: "Item \($0)") }
    }

    @Test func builderSupportsControlFlowCollectionsAndComponentFunctions() {
        func component() -> Element { Text("Component") }
        let show = true
        let collection: [Element] = [Text("Array A"), Text("Array B")]
        let view = Column {
            if show { Text("Visible") }
            if !show { Text("Wrong") } else { Text("Else") }
            for index in 0..<2 { Text("Loop \(index)") }
            switch show {
            case true: component()
            case false: Text("Wrong")
            }
            collection
        }
        #expect(UIEngine().render(view, width: 12, height: 9).prefix(7).map { $0.trimmingCharacters(in: .whitespaces) }
                == ["Visible", "Else", "Loop 0", "Loop 1", "Component", "Array A", "Array B"])
    }

    @Test func workspaceReceivesRemainderWithoutRepeatingFillModifiers() {
        let view = Column {
            Text("Header")
            Panel("Workspace") { List(id: "items", rows: rows(), selection: "0") }
            TextEditor(id: "draft", value: "one\ntwo").height(.fit(maximum: 3))
            StatusBar("Ready")
        }
        let engine = UIEngine()
        let grid = engine.render(view, width: 24, height: 12)
        #expect(grid[0].hasPrefix("Header"))
        #expect(grid[1].contains("Workspace"))
        #expect(grid[8].contains("┘"))
        #expect(grid[9].hasPrefix("one") && grid[10].hasPrefix("two"))
        #expect(grid[11].hasPrefix("Ready"))
        let smaller = engine.render(view, width: 18, height: 8)
        #expect(smaller[7].hasPrefix("Ready"))
        #expect(smaller[5].hasPrefix("one") && smaller[6].hasPrefix("two"))
    }

    @Test func rowRemeasuresWrappedChildrenAtAllocatedWidths() {
        let view = Column {
            Row(spacing: 1) {
                Text("Side").width(.fixed(5))
                Paragraph("alpha beta gamma delta").layoutSizing(width: .flexible())
            }
            Text("After")
        }
        let grid = UIEngine().render(view, width: 16, height: 6)
        #expect(grid[0].contains("alpha beta"))
        #expect(grid[1].contains("gamma"))
        #expect(grid[2].contains("delta"))
        #expect(grid[3].hasPrefix("After"))
    }

    @Test func childWidthConstraintsAffectHeightBeforeVerticalAllocation() {
        let view = Column {
            Panel("Narrow") { Paragraph("alpha beta gamma delta") }.width(.fixed(12))
            Text("After")
        }
        let grid = UIEngine().render(view, width: 40, height: 10)
        #expect(grid[1].contains("alpha beta"))
        #expect(grid[2].contains("gamma") && grid[3].contains("delta"))
        #expect(grid[5].hasPrefix("After"))
    }

    @Test func boundedWeightedSpaceRedistributesAfterACap() {
        let layout = StackLayout(axis: .horizontal)
        func child(_ preference: LayoutPreference) -> LayoutSubview {
            LayoutSubview(width: preference, height: .content) { _ in WidgetSize(width: 1, height: 1) }
        }
        let weighted = [child(.flexible(weight: 1)), child(.flexible(weight: 2))]
        #expect(layout.placeSubviews(in: WidgetSize(width: 30, height: 2), subviews: weighted).map(\.size.width) == [10, 20])
        let capped = [child(.flexible(maximum: 4)), child(.flexible())]
        #expect(layout.placeSubviews(in: WidgetSize(width: 30, height: 2), subviews: capped).map(\.size.width) == [4, 26])
        let minimums = [child(.flexible(minimum: 5)), child(.flexible())]
        #expect(layout.placeSubviews(in: WidgetSize(width: 15, height: 2), subviews: minimums).map(\.size.width) == [10, 5])
    }

    @Test func growingComposerCapsAndShrinksWhileKeepingFooterVisible() {
        func view(_ draft: String) -> Element {
            Column {
                List(id: "items", rows: rows(), selection: "0")
                Panel("Draft") { TextEditor(id: "draft", value: draft) }
                    .height(.fit(maximum: 5))
                StatusBar("Ready")
            }
        }
        let engine = UIEngine()
        let short = engine.render(view("a"), width: 20, height: 12)
        #expect(short[8].contains("Draft") && short[11].hasPrefix("Ready"))
        let long = engine.render(view(String(repeating: "long draft ", count: 20)), width: 20, height: 12)
        #expect(long[6].contains("Draft") && long[11].hasPrefix("Ready"))
        let cleared = engine.render(view(""), width: 20, height: 12)
        #expect(cleared[8].contains("Draft") && cleared[11].hasPrefix("Ready"))
    }

    @Test func existingArraysComposeWithNegotiatedContainersAndKeepTheirSizing() {
        let old = Element.column([Text("Old"), Button("Go", id: "go")])
        let mixed = Column {
            old
            Text("New")
        }
        let engine = UIEngine()
        let grid = engine.render(mixed, width: 12, height: 5)
        #expect(grid[0].hasPrefix("Old") && grid[2].hasPrefix("New"))
        #expect(engine.focus("go", in: mixed))
        #expect(engine.handle(.enter, in: mixed) == .activated("go"))
        let nested = Element.column([Column { Text("Builder inside array") }, Text("After")])
        #expect(engine.render(nested, width: 30, height: 4)[1].hasPrefix("After"))
    }

    @Test func hiddenChildrenDoNotTakeSpaceAndContentCanOverrideFlexibility() {
        let view = Column {
            Text("Hidden").visible(false)
            List(id: "items", rows: rows(2), selection: "0").height(.content)
            Text("After")
        }
        #expect(UIEngine().render(view, width: 20, height: 8)[2].hasPrefix("After"))
    }

    @Test func tinyAndEmptyLayoutsRemainBounded() {
        let view = Row(spacing: 3) {
            Panel("One") { Text("A") }.width(.fixed(40))
            Panel("Two") { Text("B") }.width(.fixed(40))
        }
        for width in 0...4 {
            for height in 0...4 {
                let grid = UIEngine().renderGrid(view, width: width, height: height)
                #expect(grid.width == width && grid.height == height)
            }
        }
        #expect(UIEngine().render(Column {}, width: 5, height: 2) == ["     ", "     "])
    }

    @Test func spacerExpandsOnlyAlongItsContainingStack() {
        let view = Column {
            Row {
                Text("Title")
                Spacer()
                Button("Quit", id: "quit")
            }
            List(id: "items", rows: rows(), selection: "0")
            StatusBar("Ready")
        }
        let grid = UIEngine().render(view, width: 30, height: 10)
        #expect(grid[0].hasPrefix("Title") && grid[0].contains("[Quit]"))
        #expect(grid[1].contains("Item 0") && grid[8].contains("Item 7"))
        #expect(grid[9].hasPrefix("Ready"))
    }

    @Test func pointerFocusAndModalRoutingWorkThroughNegotiatedContainers() {
        let root = Column {
            Row(spacing: 1) {
                Panel("Left") { Button("Left", id: "left") }.width(.fixed(12))
                Panel("Right") { Button("Go", id: "go") }.layoutSizing(width: .flexible())
            }
            TextField(id: "field", value: "")
        }
        let engine = UIEngine()
        #expect(engine.focus("field", in: root))
        _ = engine.render(root, width: 30, height: 6)
        _ = engine.handleMouseEvent(.init(.press, column: 15, row: 1))
        #expect(engine.focusedID == "go")
        _ = engine.render(root, width: 30, height: 6)
        #expect(engine.handleMouseEvent(.init(.release, column: 15, row: 1)).action == .activated("go"))
        let modal = root.overlay(Dialog(id: "modal", title: "Confirm") {
            Column { Button("Close", id: "close") }
        }.width(.fixed(12)).height(.fixed(3)))
        _ = engine.render(modal, width: 30, height: 6)
        #expect(engine.focusedID == "close")
        #expect(!engine.focus("go", in: modal))
        #expect(engine.handle(.escape, in: modal) == .dismissRequested("modal"))
        _ = engine.render(root, width: 30, height: 6)
        #expect(engine.focusedID == "go")
    }

    @Test func retainedScrollingSkipsUnrelatedWidgetsAndMatchesCompleteFrames() {
        let probe = DrawProbe()
        let root = Row(spacing: 1) {
            ScrollView(id: "scroll") {
                Column { for index in 0..<30 { Text("Line \(index)") } }
            }.width(.fixed(12))
            Element.custom(ProbeWidget(probe: probe)).width(.fill())
        }
        let engine = UIEngine()
        _ = engine.renderGrid(root, width: 24, height: 5)
        for key in [KeyEvent.down, .pageDown, .end, .home] {
            #expect(engine.handleEvent(key, in: root) == .repaint)
            let before = probe.draws
            let retained = engine.repaintGrid(width: 24, height: 5)
            #expect(probe.draws == before)
            #expect(retained == engine.renderGrid(root, width: 24, height: 5))
        }
        _ = engine.handleMouseEvent(.init(.scrollDown, column: 2, row: 2))
        let scrolled = engine.repaintGrid(width: 24, height: 5)
        #expect(scrolled.lines[0].hasPrefix("Line 3"))
    }

    @Test func alignmentPaddingAndExtremePreferencesRemainPredictable() {
        let root = Column {
            Text("Right")
            Text("Bottom").layoutSizing(width: .flexible())
        }.alignment(.trailing).padding(.all(1))
        let grid = UIEngine().render(root, width: 12, height: 5)
        #expect(grid[1] == "      Right ")
        #expect(grid[2].hasPrefix(" Bottom"))
        let extreme = Row {
            Panel("Fixed") { Text("A").width(.fixed(Int.max)) }
            Text("B").layoutSizing(width: .flexible(minimum: Int.max, maximum: Int.min, weight: Int.max))
        }
        #expect(UIEngine().renderGrid(extreme, width: 10, height: 3).width == 10)
    }

    @Test func changingThemeInvalidatesProposalMeasurements() {
        var theme = Theme.dark
        theme.normal.bold = false
        let engine = UIEngine(theme: theme)
        let root = Column {
            Element.custom(ThemeSizeWidget())
            Text("After")
        }
        #expect(engine.render(root, width: 12, height: 5)[1].hasPrefix("After"))
        theme.normal.bold = true
        engine.theme = theme
        #expect(engine.repaintGrid(width: 12, height: 5).lines[2].hasPrefix("After"))
    }
}

private final class DrawProbe { var draws = 0 }

private struct ProbeWidget: CustomWidget {
    let probe: DrawProbe
    var id: String? { nil }
    func measure(width: Int) -> WidgetSize { WidgetSize(width: 5, height: 1) }
    func draw(in canvas: inout Canvas, focused: Bool) {
        probe.draws += 1
        canvas.write("Probe", x: 0, y: 0)
    }
}

private struct ThemeSizeWidget: CustomWidget {
    var id: String? { nil }
    func measure(context: WidgetMeasureContext) -> WidgetSize {
        WidgetSize(width: 1, height: context.theme.normal.bold ? 2 : 1)
    }
}
