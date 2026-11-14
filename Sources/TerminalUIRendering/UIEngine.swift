import TerminalUICore
import TerminalUIInteraction
import TerminalUILayout
import TerminalUIText

/// Deterministic, terminal-independent rendering and interaction state.
public final class UIEngine {
    public var focusedID: String? {
        focusManager.focusedID
    }

    public var theme: Theme {
        didSet { renderer.invalidate() }
    }

    private let tree: ElementTree
    private let focusManager: FocusManager
    private let states: WidgetStateStore
    private let keyboard: KeyboardRouter
    private let pointer: PointerRouter
    private let renderer: FrameRenderer
    var textLayoutCount: Int {
        renderer.textLayoutCount
    }

    public init(theme: Theme = .init()) {
        self.theme = theme
        let tree = ElementTree()
        self.tree = tree
        let focus = FocusManager(tree: tree)
        focusManager = focus
        let states = WidgetStateStore()
        self.states = states
        let coordinates = EditorCoordinates()
        keyboard = KeyboardRouter(states: states, focus: focus, tree: tree,
                                  editor: EditorInteraction(states: states, coordinates: coordinates),
                                  collection: CollectionInteraction(states: states), shortcuts: MenuShortcutRouter())
        pointer = PointerRouter(states: states, focus: focus, tree: tree, coordinates: coordinates)
        let cache = TextLayoutCache()
        let layouts = NodeTextLayouts(cache: cache)
        let metrics = TextMetrics()
        let measurement = LayoutMeasurer(textLayouts: layouts, metrics: metrics)
        let allocation = LayoutAllocator(measurement: measurement, metrics: metrics)
        let painters = BuiltInPainters(field: FieldPainter(states: states, coordinates: coordinates),
                                       list: ListPainter(states: states, textLayouts: cache, metrics: metrics),
                                       table: TablePainter(states: states, allocation: allocation, metrics: metrics),
                                       custom: CustomWidgetPainter())
        renderer = FrameRenderer(states: states, tree: tree, textLayouts: layouts, metrics: metrics,
                                 measurement: measurement, allocation: allocation, painters: painters)
    }

    /// Focuses an enabled, visible control in the active tree. Returns false if it cannot receive focus.
    @discardableResult
    public func focus(_ id: String, in root: Element) -> Bool {
        synchronizeFocus(root)
        guard focusManager.requestFocus(id, in: root) else { return false }
        pointer.cancelPress()
        states.resumeAutomaticVisibility()
        renderer.invalidate()
        return true
    }

    /// Requests that identified content be revealed by its enclosing scroll views on the next render.
    public func keepVisible(_ id: String) {
        states.resumeAutomaticVisibility()
        renderer.keepVisible(id)
    }

    public func resetState(for id: String) {
        renderer.invalidate()
        pointer.cancelPress()
        states.reset(id: id)
        if focusedID == id { focusManager.setFocus(nil) }
    }

    public func handle(_ key: KeyEvent, in root: Element) -> UIAction? {
        handleEvent(key, in: root).action
    }

    /// Handles input and explicitly identifies viewport-only changes for retained-tree repainting.
    public func handleEvent(_ key: KeyEvent, in root: Element) -> UIEventResult {
        pointer.cancelPress()
        states.resumeAutomaticVisibility()
        renderer.invalidateGeometry()
        return apply(keyboard.handle(key, in: root, theme: theme))
    }

    /// Routes mouse input against the current rendered tree. Render again after geometry-changing input.
    /// Without current geometry, input is ignored. Mouse focus and actions follow the same modal rules as keys.
    public func handleMouseEvent(_ mouse: MouseEvent) -> UIEventResult {
        let geometry = renderer.geometry
        if geometry != nil { renderer.cancelPendingRepaint() }
        return apply(pointer.handle(mouse, geometry: geometry, theme: theme))
    }

    /// Returns a snapshot without terminal control sequences.
    public func render(_ element: Element, width: Int, height: Int) -> [String] {
        renderGrid(element, width: width, height: height).lines
    }

    public func renderGrid(_ element: Element, width: Int, height: Int) -> CellGrid {
        updateTree(element)
        return repaintGrid(width: width, height: height)
    }

    package func updateTree(_ element: Element) {
        synchronizeFocus(element)
        states.evictInactive(excluding: Set(tree.stateKeys(element)))
        renderer.updateTree(element)
    }

    /// Paints the current tree without reconciling elements or invalidating measurements.
    package func repaintGrid(width: Int, height: Int) -> CellGrid {
        pointer.resize(to: WidgetSize(width: width, height: height))
        return renderer.renderGrid(width: width, height: height, environment: RenderEnvironment(theme: theme, focusedID: focusedID))
    }

    /// Refreshes input geometry without consuming the host's pending output frame.
    package func prepareMouseInput(width: Int, height: Int) {
        if renderer.geometry == nil { _ = repaintGrid(width: width, height: height) }
    }

    private func apply(_ outcome: InteractionOutcome) -> UIEventResult {
        switch outcome {
        case .unchanged: break
        case let .viewport(id): renderer.repaintViewport(id)
        case .rebuild: renderer.invalidate()
        }
        return outcome.event
    }

    private func synchronizeFocus(_ root: Element) {
        if focusManager.synchronize(root) {
            states.resumeAutomaticVisibility()
            pointer.cancelPress()
        }
    }
}
