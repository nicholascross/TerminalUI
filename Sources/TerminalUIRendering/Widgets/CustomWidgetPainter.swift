import TerminalUICore

/// Gives custom widgets a clipped surface and composites it with the inherited background.
struct CustomWidgetPainter {
    func draw(context: ElementPaintContext, canvas: inout Canvas) {
        guard case let .custom(widget) = context.element.kind else { return }
        let width = context.contentWidth, height = context.contentHeight
        var surface = Canvas(width: width, height: height)
        surface.fill(x: 0, y: 0, width: surface.width, height: surface.height, style: context.resolved(.normal))
        widget.draw(in: &surface, context: WidgetDrawContext(size: WidgetSize(width: width, height: height),
                                                             focused: widget.id != nil && widget.id == context.focusedID,
                                                             theme: context.theme, style: context.resolved(context.element.textRole),
                                                             enabled: context.active))
        for row in 0 ..< height {
            for column in 0 ..< width {
                guard let cell = surface.grid[column, row], cell.width > 0 else { continue }
                var style = cell.style
                if style.background == .default { style.background = context.resolved(.normal).background }
                canvas.write(cell.grapheme, x: context.originX + column, y: context.originY + row,
                             style: style, clipWidth: width - column)
            }
        }
    }
}
