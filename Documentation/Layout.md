# Layout and sizing

Compose a screen with `Column`, `Row`, `Panel` and `ScrollView`. Sizes, spacing and padding use terminal cells.

## Composing a workspace

This view puts a fixed-width list beside a flexible inspector. The command panel grows with its content up to eight rows, leaving the rest of the height for the workspace.

```swift
import TerminalUI

@TerminalComponent
struct WorkspaceLayout: TerminalView {
    @State private var draft = ""

    var body: some TerminalView {
        Column(spacing: 1) {
            Row {
                Text("Workspace").role(.heading)
                Spacer()
                Text("Ready").role(.secondary)
            }

            Row(spacing: 1) {
                Panel("Files") {
                    List(id: "files", rows: [
                        ListRow(id: "notes", title: "Notes.swift"),
                        ListRow(id: "settings", title: "Settings.swift")
                    ])
                }
                .width(.fixed(26))

                Panel("Inspector") {
                    ScrollView(id: "inspector") {
                        Paragraph("Select a file to inspect its details.")
                    }
                }
            }

            Panel("Command") {
                TextEditor(id: "command", text: $draft)
                    .onSubmit { draft = "" }
            }
            .height(.fit(maximum: 8))

            StatusBar("Enter: submit · Shift+Enter: newline")
        }
    }
}
```

`Column` arranges children vertically; `Row` arranges them horizontally. Both accept `spacing:` and cross-axis `alignment:`. A `Spacer` expands along its containing stack's axis, so a spacer in a header pushes controls apart without making the header taller.

`Panel`, `ScrollView` and `Dialog` accept builder content. Use an explicit row or column inside them to choose its arrangement and spacing. You can use Swift conditionals, switches and loops in builders, and extract helpers returning `some TerminalView`.

## Automatic sizing

Most views need no explicit dimensions.

| View | Width | Height |
| --- | --- | --- |
| Text, paragraph, button | Content | Content |
| Text field, editor | Flexible | Content |
| List, table, scroll view | Flexible | Flexible |
| Panel, dialog | Child size plus borders and padding | Child size plus borders and padding |
| Menu bar, tabs, status bar, divider | Flexible | One row |

Rows and columns expand in a dimension when their content needs flexible space there. Content-only arrangements remain compact. Hidden children take no space; disabled children keep their space.

Panels forward their child's sizing preferences, including decoration. An explicit size on a panel applies to the whole panel, including borders and padding.

## Controlling dimensions

Use `.width(...)` and `.height(...)` for common sizing rules:

| Rule | Meaning | Example |
| --- | --- | --- |
| `.content` | Fit the content. | `.height(.content)` |
| `.fixed(n)` | Request a specific number of cells. | `.width(.fixed(26))` |
| `.fit(maximum: n)` | Grow with content up to a limit. | `.height(.fit(maximum: 8))` |
| `.fill(weight: n)` | Share available space by weight. | `.width(.fill(weight: 2))` |

For bounded flexible sizing, use `layoutSizing`:

```swift
@MainActor
func splitDetails(left: String, right: String) -> some TerminalView {
    Row(spacing: 1) {
        Paragraph(left)
            .layoutSizing(width: .flexible(minimum: 16, maximum: 40))
        Paragraph(right)
            .layoutSizing(width: .flexible(weight: 2))
    }
}
```

Flexible children start at their minimum and share the remaining cells by weight. A child that reaches its maximum leaves space for its siblings. Weighted shares apply to the remaining space, so minimums and maximums affect the final proportions.

`layoutSizing(width:height:)` sets both preferences; specify both in one call when needed. A later `.width` or `.height` replaces the corresponding preference.

When space is too small, content and flexible requests shrink before fixed requests. No minimum can guarantee more space than the terminal provides. Wrapped text is measured at its assigned width, so its height follows the available space.

## Padding and alignment

Use `.padding(.init(leading: 1, trailing: 1))` to inset content. Set `alignment:` on a row or column, or apply `.alignment(.center)` or `.alignment(.trailing)`, to position compact children across the stack's axis.

Single-line `Text` truncates when it does not fit. Use `Paragraph` for wrapping, and place longer content in a `ScrollView` so it can be read within the available height.

## Resizing panels with the mouse

Enable mouse motion with `TerminalConfiguration(mouseEnabled: true, mouseDragEnabled: true)`, or use `--mouse-drag` in an argument-aware app. Then give each panel you want to resize a stable ID and an edge to drag.

```swift
Row(spacing: 1) {
    Panel("Files") {
        List(id: "files", rows: files, selection: selectedFile)
    }
    .resizable(id: "files-pane", edge: .trailing, minimum: 20, maximum: 42, preferredSize: 26)

    Panel("Details") {
        ScrollView(id: "details") { Paragraph(details) }
    }
    .layoutSizing(width: .flexible(minimum: 30))
}
```

Drag the marked border. Use `.leading` or `.trailing` in a horizontal stack, and `.top` or `.bottom` in a vertical stack. The bounds and preferred size are measured in terminal cells across the panel, including borders and padding. The stack combines these with its existing size rules. A fixed dimension stays fixed during a drag, and flexible siblings on the dragged side share the change within their own limits. Trailing and bottom edges can also use spare space at the end of a stack. The handle appears when the border is visible and can move. Press Escape during a drag to restore the starting size.

TerminalUI remembers committed sizes for the session by panel ID and axis. Use unique IDs within a component. Sizes adapt to tighter layouts and recover when space returns. To save a size across launches, store it in the optional `onResize` callback and pass it as `preferredSize` when creating the view. The callback runs on the main actor when a release commits a changed size. Resize handles are supported by `Row`, `Column`, `Stack`, and their engine equivalents.

## Responsive layouts

Read `application.terminalSize` through `@ApplicationContext`. Views that read it update when the terminal changes size.

```swift
@TerminalComponent
struct ResponsiveWorkspace: TerminalView {
    @ApplicationContext private var application

    var body: some TerminalView {
        let compact = application.terminalSize.columns < 85
        Stack(axis: compact ? .vertical : .horizontal, spacing: 1) {
            Panel("Navigation") {
                List(id: "navigation", rows: [
                    ListRow(id: "overview", title: "Overview"),
                    ListRow(id: "activity", title: "Activity")
                ])
            }
            .layoutSizing(
                width: compact ? .automatic : .fixed(26),
                height: compact ? .fixed(8) : .automatic
            )

            Panel("Details") {
                ScrollView(id: "details") {
                    Paragraph("The detail pane uses the remaining space.")
                }
            }
        }
    }
}
```

Changing a single `Stack`'s axis preserves child state and focus. Switching between separate conditional `Row` and `Column` branches gives each branch a separate lifetime.

See the [layout demo](../Examples/LayoutDemo/README.md) for a complete workspace and the [repository browser](../Examples/RepositoryDemo/README.md) for responsive panes.
