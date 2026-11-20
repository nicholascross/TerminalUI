import TerminalUICore
import TerminalUIInteraction
import TerminalUILayoutEngine
import TerminalUIText

/// Deterministic, terminal-independent rendering and interaction state.
public final class UIEngine {
    public var metrics: RenderingMetrics { renderer.renderingMetrics }

    public var focusedID: String? {
        focusManager.focusedID
    }

    public var theme: Theme {
        didSet { renderer.invalidateMeasurements() }
    }

    private let tree: ElementTree
    private let focusManager: FocusManager
    private let states: WidgetStateStore
    private let keyboard: KeyboardRouter
    private let pointer: PointerRouter
    private let renderer: FrameRenderer
    private var renderedSize: WidgetSize?
    var textLayoutCount: Int {
        renderer.textLayoutCount
    }

    public convenience init(theme: Theme = .init()) {
        self.init(theme: theme, textSelectionEnabled: false)
    }

    package init(theme: Theme = .init(), textSelectionEnabled: Bool, panelResizingEnabled: Bool = true) {
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
        let layouts = NodeTextLayouts(cache: cache, tracksSource: textSelectionEnabled)
        let metrics = TextMetrics()
        let measurement = LayoutMeasurer(textLayouts: layouts, metrics: metrics, panelSize: { states[$0].panelSize })
        let allocation = LayoutAllocator(measurement: measurement, metrics: metrics)
        let painters = BuiltInPainters(field: FieldPainter(states: states, coordinates: coordinates),
                                       list: ListPainter(states: states, textLayouts: cache, metrics: metrics),
                                       table: TablePainter(states: states, allocation: allocation, metrics: metrics),
                                       custom: CustomWidgetPainter())
        renderer = FrameRenderer(states: states, tree: tree, textLayouts: layouts, metrics: metrics,
                                 measurement: measurement, allocation: allocation, painters: painters, panelResizingEnabled: panelResizingEnabled)
    }

    /// Focuses an enabled, visible control in the active tree. Returns false if it cannot receive focus.
    @discardableResult
    public func focus(_ id: String, in root: Element) -> Bool {
        synchronizeFocus(root)
        guard focusManager.requestFocus(id, in: root) else { return false }
        cancelPointerPress()
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
        cancelPointerPress()
        states.reset(id: id)
        renderer.invalidateLayout()
        if focusedID == id { focusManager.setFocus(nil) }
    }

    package func resetFocus() {
        focusManager.reset()
        cancelPointerPress()
    }

    public func handle(_ key: KeyEvent, in root: Element) -> UIAction? {
        handleEvent(key, in: root).action
    }

    /// Handles input and identifies changes that can reuse the retained tree.
    public func handleEvent(_ key: KeyEvent, in root: Element) -> UIEventResult {
        let cancelledResize = key == .escape && pointer.isResizingPanel
        cancelPointerPress()
        if cancelledResize { return .repaint }
        states.resumeAutomaticVisibility()
        renderer.invalidateGeometry()
        return apply(keyboard.handle(key, in: root, theme: theme))
    }

    /// Routes mouse input against the current rendered tree. Render again after geometry-changing input.
    /// Without current geometry, input is ignored. Mouse focus and actions follow the same modal rules as keys.
    public func handleMouseEvent(_ mouse: MouseEvent) -> UIEventResult {
        handleMouseEvent(mouse, copySelection: { _ in })
    }

    package func handleMouseEvent(
        _ mouse: MouseEvent, copySelection: (String) -> Void,
        panelResized: (_ callback: @MainActor (Int) -> Void, _ size: Int) -> Void = { _, _ in },
    ) -> UIEventResult {
        let geometry = renderer.geometry
        if geometry != nil { renderer.cancelPendingRepaint() }
        let outcome = pointer.handle(mouse, geometry: geometry, theme: theme)
        if case let .textSelection(copy?) = outcome, !copy.isEmpty { copySelection(copy) }
        let result = apply(outcome)
        if case let .panelResize(_, commit?) = outcome { panelResized(commit.callback, commit.size) }
        return result
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
        synchronizeFocus(element, preservingSelection: true)
        states.evictInactive(excluding: Set(tree.stateKeys(element)))
        pointer.reconcileSelection(in: renderer.updateTree(element))
    }

    /// Paints the current tree without reconciling elements or invalidating measurements.
    package func repaintGrid(width: Int, height: Int) -> CellGrid {
        let size = WidgetSize(width: width, height: height)
        if let restored = pointer.resize(to: size) { renderer.invalidateLayout(at: restored) }
        renderedSize = size
        func paint() -> CellGrid {
            renderer.renderGrid(width: width, height: height,
                                environment: RenderEnvironment(theme: theme, focusedID: focusedID)) { geometry in
                if let geometry { pointer.refreshScrolledSelection(in: geometry) }
                return pointer.textSelection
            }
        }
        let frame = paint()
        if let restored = pointer.validatePanelDrag(in: renderer.geometry) {
            renderer.invalidateLayout(at: restored)
            return paint()
        }
        return frame
    }

    /// Refreshes input geometry without consuming the host's pending output frame.
    package func prepareMouseInput(width: Int, height: Int) {
        if renderer.geometry == nil || renderedSize != WidgetSize(width: width, height: height) {
            _ = repaintGrid(width: width, height: height)
        }
    }

    package var canAutoscrollSelection: Bool {
        renderer.geometry != nil && pointer.canAutoscrollSelection
    }

    package func autoscrollSelection() -> Bool {
        guard renderer.geometry != nil, case let .viewport(id) = pointer.autoscrollSelection() else { return false }
        _ = apply(.viewport(id))
        return true
    }

    private func apply(_ outcome: InteractionOutcome) -> UIEventResult {
        switch outcome {
        case .unchanged: break
        case let .viewport(id): renderer.repaintViewport(id)
        case .rebuild: renderer.invalidate()
        case .textSelection: renderer.repaintTextSelection()
        case let .panelResize(node, _): renderer.invalidateLayout(at: node)
        }
        return outcome.event
    }

    private func synchronizeFocus(_ root: Element, preservingSelection: Bool = false) {
        if focusManager.synchronize(root) {
            states.resumeAutomaticVisibility()
            if let restored = pointer.cancelPress(preservingSelection: preservingSelection) {
                renderer.invalidateLayout(at: restored)
            }
        }
    }

    package func cancelPointerPress() {
        if let restored = pointer.cancelPress() { renderer.invalidateLayout(at: restored) }
    }
}
