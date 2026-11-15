/// The built-in control painters share the injected state and layout services.
struct BuiltInPainters {
    let field: FieldPainter
    let list: ListPainter
    let table: TablePainter
    let custom: CustomWidgetPainter
}
