import TerminalUICore
import TerminalUIInteraction
import TerminalUILayoutEngine
import TerminalUIText

struct RenderEnvironment {
    let theme: Theme
    let focusedID: String?
}

/// Owns retained rendering and geometry lifetime; input services never receive this object.
final class FrameRenderer {
    private let states: WidgetStateStore
    private let tree: ElementTree
    private let nodeTextLayouts: NodeTextLayouts
    private let metrics: TextMetrics
    private let measurement: LayoutMeasurer
    private let allocation: LayoutAllocator
    private let painters: BuiltInPainters
    private let panelResizingEnabled: Bool
    private let statistics = RenderingStatistics()
    var renderingMetrics: RenderingMetrics { statistics.metrics }
    private var layoutRoot: LayoutNode?
    private var retainedCanvas: Canvas?
    private var pendingScrollID: String?
    private var selectionRepaintPending = false
    private var visibilityTarget: String?
    private var focusedBounds: (y: Int, height: Int)?
    private var mouseTranslation = (column: 0, row: 0)
    private var mouseClip = MouseRect(column: 0, row: 0, width: 0, height: 0)
    private(set) var geometry: RenderedGeometry?
    var textLayoutCount: Int {
        nodeTextLayouts.layoutCount
    }

    init(
        states: WidgetStateStore,
        tree: ElementTree,
        textLayouts: NodeTextLayouts,
        metrics: TextMetrics,
        measurement: LayoutMeasurer,
        allocation: LayoutAllocator,
        painters: BuiltInPainters,
        panelResizingEnabled: Bool = true,
    ) {
        self.states = states
        self.tree = tree
        nodeTextLayouts = textLayouts
        self.metrics = metrics
        self.measurement = measurement
        self.allocation = allocation
        self.painters = painters
        self.panelResizingEnabled = panelResizingEnabled
    }

    func invalidateGeometry() {
        geometry?.invalidate()
        geometry = nil
        selectionRepaintPending = false
    }

    func invalidateMeasurements() {
        layoutRoot?.invalidateMeasurements()
        invalidate()
    }

    func invalidateLayout(at node: LayoutNode? = nil) {
        layoutRoot?.invalidateLayout(at: node)
        invalidate()
    }

    func invalidate() {
        invalidateGeometry()
        retainedCanvas = nil
        pendingScrollID = nil
    }

    func cancelPendingRepaint() {
        pendingScrollID = nil
    }

    func repaintViewport(_ id: String) {
        pendingScrollID = id
        invalidateGeometry()
    }

    func repaintTextSelection() {
        selectionRepaintPending = true
    }

    func keepVisible(_ id: String) {
        visibilityTarget = id
        invalidate()
    }

    func updateTree(_ element: Element) {
        invalidate()
        if let layoutRoot {
            layoutRoot.update(element)
        } else {
            layoutRoot = LayoutNode(element, statistics: statistics)
        }
    }

    /// Paints without reconciling elements or invalidating measurements.
    func renderGrid(
        width: Int, height: Int, environment: RenderEnvironment, selection: (RenderedGeometry?) -> SelectableCell? = { _ in nil },
    ) -> CellGrid {
        statistics.metrics.frames += 1
        let theme = environment.theme
        let previous = retainedCanvas.flatMap { $0.width == width && $0.height == height ? $0 : nil }
        if selectionRepaintPending, let previous, geometry != nil {
            selectionRepaintPending = false
            return frame(from: previous, selection: selection(geometry), theme: theme)
        }
        invalidateGeometry()
        focusedBounds = nil
        mouseTranslation = (0, 0)
        mouseClip = MouseRect(column: 0, row: 0, width: max(0, width), height: max(0, height))
        let path = pendingScrollID.flatMap { layoutRoot?.repaintPath(toScroll: $0) }
        let repaintPath: [LayoutNode]?
        var canvas: Canvas
        if let previous, let path {
            repaintPath = path
            canvas = previous
        } else {
            repaintPath = nil
            canvas = Canvas(width: width, height: height)
            canvas.fill(x: 0, y: 0, width: canvas.width, height: canvas.height, style: theme.normal)
        }
        if let layoutRoot {
            paint(layoutRoot, x: 0, y: 0, width: canvas.width, height: canvas.height,
                  canvas: &canvas, environment: environment, repaintPath: repaintPath?[...])
        }
        visibilityTarget = nil
        pendingScrollID = nil
        retainedCanvas = canvas
        if width > 0, height > 0, let layoutRoot {
            geometry = RenderedGeometry(root: layoutRoot, selectableCells: canvas.selectableCells)
        }
        return frame(from: canvas, selection: selection(geometry), theme: theme)
    }

    private func frame(from canvas: Canvas, selection: SelectableCell?, theme: Theme) -> CellGrid {
        if let selection {
            return canvas.grid.highlighting(selection, in: canvas.selectableCells, style: theme.selection)
        }
        return canvas.grid
    }

    // The element switch is the central drawing dispatcher for all built-in controls.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func paint(
        _ node: LayoutNode,
        x originX: Int,
        y originY: Int,
        width: Int,
        height: Int,
        canvas: inout Canvas,
        environment: RenderEnvironment,
        inherited: StyleOverride = .init(),
        enabled: Bool = true,
        repaintPath: ArraySlice<LayoutNode>? = nil,
    ) {
        let theme = environment.theme
        let focusedID = environment.focusedID
        if let repaintPath, repaintPath.first !== node { return }
        // Preserve ancestor backgrounds and skip siblings until the complete repaint boundary is reached.
        let remainingPath = repaintPath.flatMap { $0.count > 1 ? $0.dropFirst() : nil }
        let element = node.element
        node.mouse = nil
        guard element.isVisible, width > 0, height > 0 else { return }
        statistics.metrics.paints += 1
        if remainingPath == nil, element.styleOverride.background != nil {
            canvas.fill(x: originX, y: originY, width: width, height: height,
                        style: inherited.merging(element.styleOverride).applying(to: theme.normal))
        }
        let left = min(width, element.insets.leading), top = min(height, element.insets.top)
        let contentWidth = max(0, width - left - min(width - left, element.insets.trailing))
        let contentHeight = max(0, height - top - min(height - top, element.insets.bottom))
        let originX = originX + left, originY = originY + top
        guard contentWidth > 0, contentHeight > 0 else { return }
        let active = enabled && element.isEnabled
        let bounds = MouseRect(column: originX + mouseTranslation.column, row: originY + mouseTranslation.row,
                               width: contentWidth, height: contentHeight)
        let previousClip = mouseClip
        mouseClip = mouseClip.intersecting(bounds)
        defer { mouseClip = previousClip }
        node.mouse = MouseGeometry(bounds: bounds, clip: mouseClip, enabled: active)
        if let target = visibilityTarget, element.visibilityID == target {
            focusedBounds = (originY, contentHeight)
        } else {
            let target = visibilityTarget ?? focusedID
            switch element.kind {
            case let .button(_, id), let .field(id, _, _, _), let .list(id, _, _), let .table(id, _, _, _, _), let .scroll(id, _):
                if id == target { focusedBounds = (originY, contentHeight) }
            case let .custom(widget):
                if widget.id != nil, widget.id == target { focusedBounds = (originY, contentHeight) }
            default: break
            }
        }
        let intersectsViewport = originY < canvas.visibleRows.upperBound && originY + contentHeight > canvas.visibleRows.lowerBound
        if !intersectsViewport {
            guard let target = visibilityTarget ?? focusedID, tree.containsTarget(element, id: target) else { return }
        }
        let descendants = inherited.merging(element.styleOverride)
        let context = ElementPaintContext(element: element, theme: theme, inherited: inherited, active: active,
                                          focusedID: focusedID, originX: originX, originY: originY,
                                          contentWidth: contentWidth, contentHeight: contentHeight,
                                          bounds: bounds, manuallyScrolled: states.manuallyScrolled)
        func resolved(_ role: TextRole, state: TextRole? = nil) -> TextStyle {
            context.resolved(role, state: state)
        }
        let selectable = nodeTextLayouts.tracksSource && active && element.isTextSelectable
        func write(_ text: String, _ row: Int, _ col: Int = 0, style: TextStyle? = nil, sourceMap: TextSourceMap? = nil) {
            let selection = sourceMap.map { Canvas.SelectionSource.mapped(ObjectIdentifier(node), $0) }
            context.write(text, row: row, column: col, style: style, canvas: &canvas, selection: selection)
        }
        if let stack = measurement.resizableStack(of: node, theme: theme) {
            let plan = stack.plan(LayoutProposal(width: contentWidth, height: contentHeight))
            paintLayoutChildren(node, placements: plan.placements, context: context, canvas: &canvas, environment: environment,
                                inherited: descendants, repaintPath: remainingPath)
            if panelResizingEnabled, active, let resize = plan.resize {
                paintResizeHandles(node, allocation: resize, style: resolved(.accent), glyph: theme.borders.cross, canvas: &canvas)
            }
            return
        }
        switch element.kind {
        case .component: preconditionFailure("Resolve components with ComponentApplication before rendering")
        case .boundary:
            paint(node.children[0], x: originX, y: originY, width: contentWidth, height: contentHeight,
                  canvas: &canvas, environment: environment, inherited: descendants, enabled: active, repaintPath: remainingPath)
        case let .text(text):
            let line = String(text.prefix(100000).prefix { $0 != "\n" && $0 != "\r" && $0 != "\r\n" })
            let truncated = metrics.truncate(line, width: contentWidth)
            let offset = allocation.alignedOffset(contentWidth - metrics.cellLength(truncated), element.alignment)
            write(truncated, 0, offset, sourceMap: selectable ? sourceMap(for: truncated, in: line) : nil)
        case let .paragraph(text):
            let layout = nodeTextLayouts.layout(text, width: contentWidth, retaining: node)
            let lines = layout.lines
            let first = max(0, canvas.visibleRows.lowerBound - originY)
            let end = min(lines.count, contentHeight, canvas.visibleRows.upperBound - originY)
            if first < end {
                for index in first ..< end {
                    let line = lines[index]
                    let offset = element.alignment == nil ? 0 : allocation.alignedOffset(contentWidth - metrics.cellLength(line), element.alignment)
                    write(line, index, offset, sourceMap: selectable ? layout.sourceMaps?[index] : nil)
                }
            }
        case let .styledParagraph(spans):
            let lines = nodeTextLayouts.layout(spans, width: contentWidth, retaining: node).lines
            let first = max(0, canvas.visibleRows.lowerBound - originY)
            let end = min(lines.count, contentHeight, canvas.visibleRows.upperBound - originY)
            guard first < end else { break }
            for row in first ..< end {
                let line = lines[row]
                let offset = allocation.alignedOffset(contentWidth - line.width, element.alignment)
                for run in line.runs {
                    let span = spans[run.spanIndex]
                    write(run.text, row, offset + run.column, style: span.style.applying(to: resolved(span.role)),
                          sourceMap: selectable ? run.sourceMap : nil)
                }
            }
        case let .button(title, id):
            let role: TextRole = if case .normal = element.textRole { .action } else { element.textRole }
            write("\(focusedID == id ? ">" : " ")[\(title)]\(active ? "" : " (disabled)")", 0,
                  style: resolved(role, state: focusedID == id ? .focused : nil))
        case .field:
            painters.field.draw(node: node, context: context, canvas: &canvas)
        case .list:
            painters.list.draw(node: node, context: context, canvas: &canvas)
        case .table:
            painters.table.draw(node: node, context: context, canvas: &canvas)
        case let .scroll(id, _):
            let child = node.children[0]
            let stateID = "scroll:" + id
            let wasAtEnd = (states[stateID].viewport.offset ?? 0) >= (states[stateID].viewport.limit ?? 0)
            states[stateID].viewport.height = contentHeight
            let totalHeight = min(4096, max(contentHeight, measurement.measure(child, width: contentWidth, theme: theme).1))
            states[stateID].viewport.limit = max(0, totalHeight - contentHeight)
            var offset = min(max(0, states[stateID].viewport.offset ?? 0), max(0, totalHeight - contentHeight))
            if element.followsEnd, wasAtEnd { offset = max(0, totalHeight - contentHeight) }
            let outerBounds = focusedBounds
            func renderContent(at offset: Int) -> Canvas {
                let translation = mouseTranslation
                mouseTranslation = (translation.column + originX, translation.row + originY - offset)
                defer { mouseTranslation = translation }
                var inner = Canvas(width: contentWidth, height: totalHeight, viewport: offset ..< (offset + contentHeight))
                inner.fill(x: 0, y: offset, width: inner.width, height: contentHeight, style: resolved(.normal))
                focusedBounds = nil
                paint(
                    child,
                    x: 0,
                    y: 0,
                    width: contentWidth,
                    height: totalHeight,
                    canvas: &inner,
                    environment: environment,
                    inherited: descendants,
                    enabled: active,
                )
                return inner
            }
            var inner = renderContent(at: offset)
            if !states.manuallyScrolled.contains(stateID), let bounds = focusedBounds, (visibilityTarget ?? focusedID) != id {
                let previousOffset = offset
                if bounds.y < offset { offset = bounds.y }
                if bounds.y + bounds.height > offset + contentHeight {
                    offset = min(bounds.y, bounds.y + bounds.height - contentHeight)
                }
                offset = min(max(0, offset), states[stateID].viewport.limit ?? 0)
                if offset != previousOffset { inner = renderContent(at: offset) }
                let bounds = focusedBounds ?? bounds
                focusedBounds = (originY + bounds.y - offset, min(bounds.height, contentHeight))
            } else {
                focusedBounds = outerBounds
            }
            states[stateID].viewport.offset = offset
            for row in 0 ..< inner.grid.height where canvas.visibleRows.contains(originY + row) {
                for column in 0 ..< inner.grid.width {
                    guard let cell = inner.grid[column, row], cell.width > 0 else { continue }
                    let selection = inner.selectableCells[row]?[column].map(Canvas.SelectionSource.cell)
                    canvas.write(cell.grapheme, x: originX + column, y: originY + row, style: cell.style,
                                 clipWidth: contentWidth - column, selection: selection)
                }
            }
        case .custom:
            UIEvaluationPhase.perform("painting") { painters.custom.draw(context: context, canvas: &canvas) }
        case .divider: write(String(repeating: theme.borders.horizontal, count: contentWidth), 0, style: resolved(.border))
        case .spacer: break
        case let .panel(title, _), let .dialog(_, title, _):
            let child = node.children[0]
            let borderRole: TextRole = if case .dialog = element.kind { .dialog } else { .border }
            let borderStyle = resolved(borderRole, state: tree.containsFocus(element, id: focusedID) ? .activeBorder : nil)
            let horizontal = String(repeating: theme.borders.horizontal, count: max(0, contentWidth - 2))
            write(theme.borders.topLeft + horizontal + (contentWidth > 1 ? theme.borders.topRight : ""), 0, style: borderStyle)
            if contentWidth > 4 {
                let marker = tree.containsFocus(child.element, id: focusedID) ? ">" : " "
                canvas.write(marker + title + " ", x: originX + 1, y: originY, style: resolved(.heading), clipWidth: contentWidth - 2)
            }
            if contentHeight > 1 {
                write(
                    theme.borders.bottomLeft + horizontal + (contentWidth > 1 ? theme.borders.bottomRight : ""),
                    contentHeight - 1,
                    style: borderStyle,
                )
            }
            if contentHeight > 2 {
                for line in 1 ..< (contentHeight - 1) {
                    write(theme.borders.vertical, line, style: borderStyle)
                    if contentWidth > 1 { write(theme.borders.vertical, line, contentWidth - 1, style: borderStyle) }
                }
                if contentWidth > 2 {
                    paint(child, x: originX + 1, y: originY + 1, width: contentWidth - 2, height: contentHeight - 2,
                          canvas: &canvas, environment: environment, inherited: descendants, enabled: active, repaintPath: remainingPath)
                }
                // Join full-width dividers to the existing outline, without changing layout.
                if contentWidth > 2 {
                    for line in 1 ..< (contentHeight - 1) where (1 ..< (contentWidth - 1)).allSatisfy({
                        canvas.cell(atX: originX + $0, y: originY + line)?.grapheme == theme.borders.horizontal
                    }) {
                        let style = canvas.cell(atX: originX + 1, y: originY + line)?.style ?? resolved(borderRole)
                        write(theme.borders.leftJoin, line, style: style)
                        write(theme.borders.rightJoin, line, contentWidth - 1, style: style)
                    }
                }
            }
        case let .layout(strategy, _):
            let size = WidgetSize(width: contentWidth, height: contentHeight)
            let placements = strategy.placeSubviews(in: size, subviews: measurement.subviews(of: node, theme: theme), alignment: element.alignment)
            paintLayoutChildren(node, placements: placements, context: context, canvas: &canvas, environment: environment,
                                inherited: descendants, repaintPath: remainingPath)
        case let .column(spacing, _), let .row(spacing, _):
            let vertical = if case .column = element.kind { true } else { false }
            let children = node.children.filter(\.element.isVisible)
            guard !children.isEmpty else { return }
            let length = vertical ? contentHeight : contentWidth
            let gap = min(spacing, length)
            let available = max(0, length - min(length, gap * min(children.count - 1, length)))
            let sizes = allocation.allocate(children, length: available, width: contentWidth, vertical: vertical, theme: theme)
            var offset = 0
            for (index, child) in children.enumerated() {
                let part = min(sizes[index], max(0, length - offset))
                let crossAvailable = vertical ? contentWidth : contentHeight
                let rule = vertical ? child.element.widthRule : child.element.heightRule
                let cross: Int
                switch rule {
                case let .fixed(value): cross = min(crossAvailable, max(0, value))
                case .fit:
                    let measured = measurement.measure(child, width: vertical ? contentWidth : part, theme: theme)
                    cross = min(crossAvailable, vertical ? measured.0 : measured.1)
                case .content where element.alignment != nil:
                    let measured = measurement.measure(child, width: vertical ? contentWidth : part, theme: theme)
                    cross = min(crossAvailable, vertical ? measured.0 : measured.1)
                default: cross = crossAvailable
                }
                let crossOffset = allocation.alignedOffset(crossAvailable - cross, element.alignment)
                if vertical {
                    paint(child, x: originX + crossOffset, y: originY + offset, width: cross, height: part,
                          canvas: &canvas, environment: environment, inherited: descendants, enabled: active, repaintPath: remainingPath)
                } else {
                    paint(child, x: originX + offset, y: originY + crossOffset, width: part, height: cross,
                          canvas: &canvas, environment: environment, inherited: descendants, enabled: active, repaintPath: remainingPath)
                }
                offset += part + min(gap, max(0, length - offset - part))
            }
        case .overlay:
            let base = node.children[0], top = node.children[1]
            paint(
                base,
                x: originX,
                y: originY,
                width: contentWidth,
                height: contentHeight,
                canvas: &canvas,
                environment: environment,
                inherited: descendants,
                enabled: active,
            )
            canvas.fill(x: originX, y: originY, width: contentWidth, height: contentHeight, style: resolved(.normal))
            paint(
                top,
                x: originX,
                y: originY,
                width: contentWidth,
                height: contentHeight,
                canvas: &canvas,
                environment: environment,
                inherited: descendants,
                enabled: active,
            )
        }
    }

    private func paintLayoutChildren(
        _ node: LayoutNode, placements: [LayoutPlacement], context: ElementPaintContext, canvas: inout Canvas,
        environment: RenderEnvironment, inherited: StyleOverride, repaintPath: ArraySlice<LayoutNode>?,
    ) {
        let children = node.children.filter(\.element.isVisible)
        var placed = Set<Int>()
        for placement in placements where children.indices.contains(placement.index) && placed.insert(placement.index).inserted {
            let x = min(context.contentWidth, placement.x), y = min(context.contentHeight, placement.y)
            paint(children[placement.index], x: context.originX + x, y: context.originY + y,
                  width: min(context.contentWidth - x, placement.size.width), height: min(context.contentHeight - y, placement.size.height),
                  canvas: &canvas, environment: environment, inherited: inherited, enabled: context.active, repaintPath: repaintPath)
        }
    }

    private func paintResizeHandles(
        _ node: LayoutNode, allocation: StackResizeAllocation, style: TextStyle, glyph: String, canvas: inout Canvas,
    ) {
        let children = node.children.filter(\.element.isVisible)
        let handles = children.enumerated().compactMap { index, child -> PanelResizeHandle? in
            guard let range = allocation.travel(for: index), range.lowerBound < range.upperBound,
                  let panel = child.resizablePanel, let edge = panel.element.panelResize?.edge,
                  let geometry = panel.mouse, geometry.enabled, let clip = child.mouse?.clip else { return nil }
            let bounds = geometry.bounds
            let border: MouseRect
            if edge.vertical {
                guard bounds.width > 1, bounds.height > 1 else { return nil }
                let row = edge.isEnd ? bounds.row + bounds.height - 1 : bounds.row
                border = MouseRect(column: bounds.column, row: row, width: bounds.width, height: 1)
            } else {
                guard bounds.width > 1, bounds.height > 2 else { return nil }
                let column = edge.isEnd ? bounds.column + bounds.width - 1 : bounds.column
                border = MouseRect(column: column, row: bounds.row + 1, width: 1, height: bounds.height - 2)
            }
            let hit = border.intersecting(geometry.clip).intersecting(clip)
            guard hit.width > 0, hit.height > 0 else { return nil }
            let column = edge == .top ? hit.column + hit.width - 1 : hit.column + hit.width / 2
            let row = hit.row + hit.height / 2
            let x = column - mouseTranslation.column, y = row - mouseTranslation.row
            var markerStyle = panel.element.styleOverride.applying(to: style)
            if let cell = canvas.cell(atX: x, y: y) { markerStyle.background = cell.style.background }
            canvas.write(glyph, x: x, y: y, style: markerStyle, clipWidth: 1)
            return PanelResizeHandle(index: index, panel: panel, bounds: hit)
        }
        if !handles.isEmpty { node.mouse?.resize = StackResizeGeometry(allocation: allocation, handles: handles) }
    }

    private func sourceMap(for drawn: String, in original: String) -> TextSourceMap {
        // The ellipsis added by truncation is decoration.
        let content = drawn == original ? drawn[...] : drawn.dropLast()
        var map = TextSourceMap()
        let count = content.utf8.count
        map.append(byteCount: count, source: 0 ..< count)
        return map
    }
}
