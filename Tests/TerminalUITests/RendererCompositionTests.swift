import TerminalUI
import TerminalUIInteraction
import TerminalUILayout
@testable import TerminalUIRendering
import TerminalUIText
import Testing

struct RendererCompositionTests {
    @Test(arguments: [false, true])
    func `pointer dispatch rejects expired geometry while a matching press survives a rebuild`(useCurrentGeometry: Bool) throws {
        let tree = ElementTree()
        let states = WidgetStateStore()
        let focus = FocusManager(tree: tree)
        let coordinates = EditorCoordinates()
        let cache = TextLayoutCache()
        let layouts = NodeTextLayouts(cache: cache)
        let metrics = TextMetrics()
        let measurement = LayoutMeasurer(textLayouts: layouts, metrics: metrics)
        let allocation = LayoutAllocator(measurement: measurement, metrics: metrics)
        let painters = BuiltInPainters(field: FieldPainter(states: states, coordinates: coordinates),
                                       list: ListPainter(states: states, textLayouts: cache, metrics: metrics),
                                       table: TablePainter(states: states, allocation: allocation, metrics: metrics),
                                       custom: CustomWidgetPainter())
        let renderer = FrameRenderer(states: states, tree: tree, textLayouts: layouts, metrics: metrics,
                                     measurement: measurement, allocation: allocation, painters: painters)
        let pointer = PointerRouter(states: states, focus: focus, tree: tree, coordinates: coordinates)
        let root = Element.button("Open", id: "open")
        focus.synchronize(root)
        pointer.resize(to: WidgetSize(width: 12, height: 1))
        let environment = RenderEnvironment(theme: Theme(), focusedID: focus.focusedID)
        renderer.updateTree(root)
        _ = renderer.renderGrid(width: 12, height: 1, environment: environment)
        let previous = try #require(renderer.geometry)
        #expect(pointer.handle(.init(.press, column: 2, row: 0), geometry: previous, theme: Theme()).event == .rebuild(action: nil))

        // A press normally rebuilds the view before the matching release arrives.
        renderer.invalidate()
        renderer.updateTree(root)
        _ = renderer.renderGrid(width: 12, height: 1, environment: environment)
        let current = try #require(renderer.geometry)
        let result = pointer.handle(.init(.release, column: 2, row: 0), geometry: useCurrentGeometry ? current : previous, theme: Theme())
        #expect(result.event == (useCurrentGeometry ? .rebuild(action: .activated("open")) : .repaint))
    }
}
