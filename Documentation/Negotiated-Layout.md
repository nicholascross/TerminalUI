# Negotiated layout

Import `TerminalUI` for typed declarative composition. Containers lower to the existing negotiated layout engine; application bodies return `some TerminalView`. Raw element factories, the legacy `ElementBuilder`, and custom layout contracts are available through `TerminalUIEngine`.

```swift
import TerminalUI

func workspace(draft: String, rows: [ListRow], selection: String?) -> some TerminalView {
    Column(spacing: 1) {
        Row {
            Text("Workspace").role(.heading)
            Spacer()
            Button("Refresh", id: "refresh")
        }

        Row(spacing: 1) {
            Panel("Files") {
                List(id: "files", rows: rows, selection: selection)
            }.width(.fixed(26))

            Panel("Inspector") {
                ScrollView(id: "inspector") {
                    Paragraph("Select a file to inspect its details.")
                }
            }
        }

        Panel("Command") {
            TextEditor(id: "command", value: draft)
                .onSubmit("submit")
        }.height(.fit(maximum: 8))

        StatusBar("Enter: submit · Shift+Enter: newline")
    }
}
```

Run `swift run LayoutDemo` for an interactive example or `swift run LayoutDemo --preview` for an 80×24 plain-text snapshot.

The demo has a persistent navigation bar: Alt+1, Alt+2 and Alt+3 focus Topics, Inspector and Command respectively. Control+1–3 also work when reported distinctly by the terminal. Ctrl-P opens searchable pane commands; Escape closes the menu and restores focus. Shortcuts preserve the draft. Plain digits and pasted digits remain editor data. The toolbar also supports clicking and focused keyboard navigation.

Mouse clicks and wheel scrolling are enabled in this demo. Use `swift run LayoutDemo --no-mouse` to preserve the terminal's normal text-selection behavior.

In the command editor, Enter submits and clears the draft, while Shift+Enter inserts a newline. Multiline paste remains text and does not submit. Ctrl-D has no submission binding.

## Composition

`Column` and `Row` accept multiple typed children, conditionals, switches, loops and availability checks. Generic builders preserve structural slots and branch identity. Use `ForEach` for keyed collections; ordinary loops have positional identity. Extract helpers returning `some TerminalView`.

`Panel`, `ScrollView` and `Dialog` accept builder content. A single root is used directly; multiple roots are grouped vertically. Put an explicit row or column inside when choosing arrangement and spacing.

Named helpers cover the existing controls, including `MenuBar`, searchable `Menu`, `Tabs`, `Progress`, `KeyHints` and engine `Custom`. Menu bars, tabs and key hints use one row and flexible width; they retain the underlying controls' shortcut, modal and input semantics. For example:

```swift
MenuBar(id: "navigation", items: [
    MenuItem(id: "pane.files", title: "Files", shortcut: "1",
             globalShortcuts: [.altCharacter("1"), .controlCharacter("1")])
], selection: nil)
```

Handle activation with `.onAction` and request focus through an installed `@ApplicationContext`. The application owns destinations.

The engine retains array-based layout and raw negotiated factories. Explicit bridge consumers can mix typed and raw content:

```swift
import TerminalUI
import TerminalUIEngine
import TerminalUIBridge

let legacy = Element.column([.text("Existing"), .button("Open", id: "open")])
let composed = TerminalUI.Column {
    EngineContent(legacy)
    TerminalUI.Text("New composition")
}
let existingRoot = Element.column([engineElement(composed), .statusBar("Ready")])
```

An ordinary stack's own allocation rules remain in force. For example, use `.height(.fill())` when a negotiated container should expand as a child of an ordinary column. Negotiated parents recognize explicit `.width`/`.height` rules on ordinary children.

## Size negotiation

Each parent offers optional width and height proposals in integer cells. A nil dimension asks for the child's ideal size. The layout measures children, reserves fixed/content dimensions, distributes remaining space among flexible children, and then remeasures at assigned sizes. In particular, a row remeasures wrapped text at its assigned width before reporting its height.

Automatic preferences are:

| Element | Width | Height |
| --- | --- | --- |
| Text, paragraph, button, custom widget | Content | Content |
| Field, editor | Flexible | Content |
| List, table, scroll view | Flexible | Flexible |
| Panel, dialog | Child preference plus decoration | Child preference plus decoration |
| Negotiated row/column | Flexible if a child expands horizontally | Flexible if a child expands vertically |
| Spacer | Flexible on its containing stack's axis | Flexible on its containing stack's axis |
| Named `StatusBar`, `Divider`, `KeyHints`, `MenuBar`, `Tabs` | Flexible | One row |

A spacer does not make a horizontal header grow vertically. An empty stack measures zero. Hidden children do not participate in measurement, spacing or placement. Disabled children retain their layout space, with existing interaction rules.

Content-only compositions remain compact. Workspace compositions containing lists or scroll views naturally become flexible. A panel forwards fixed and bounded child preferences including its two border cells and padding; explicit sizing on the panel applies to the complete decorated panel.

Use existing modifiers for common overrides:

```swift
Panel("Sidebar") { List(id: "items", rows: rows, selection: selection) }
    .width(.fixed(26))

TextEditor(id: "draft", value: draft)
    .height(.fit(maximum: 6))

List(id: "items", rows: rows, selection: selection)
    .height(.content)
```

Use `layoutSizing` for the richer preferences of negotiated parents:

```swift
Row {
    Paragraph(left).layoutSizing(width: .flexible(minimum: 10, maximum: 40, weight: 1))
    Paragraph(right).layoutSizing(width: .flexible(weight: 2))
}
```

Preferences are `.automatic`, `.content`, `.fixed`, `.fit(maximum:)` and `.flexible(minimum:maximum:weight:)`. A flexible child starts at its minimum; remaining cells are distributed by weight. A child reaching its maximum leaves its unused share available to other flexible children. Integer remainders go deterministically to later children. A later `.width` or `.height` modifier replaces the corresponding negotiated override. `layoutSizing` sets both negotiated preferences; supply both in one call when overriding both axes.

`layoutSizing` only affects negotiated allocation, leaving the ordinary array stack allocator intact. In impossible constraints non-fixed sizes shrink proportionally first, then fixed sizes shrink if necessary. Minimums cannot guarantee space larger than the terminal. All proposals and placements are bounded to 4,096 cells per dimension, matching the existing text/layout limits.

`Row` and `Column` accept a cross-axis `alignment` parameter; the existing `.alignment` modifier can override it. Content children align within the offered cross dimension, while flexible children use it subject to their bounds.

## Module and engine boundary

`TerminalUILayoutEngine` owns retained nodes, measurement, geometry and the ordinary stack allocator. The declarative module and engine facade both use Core's negotiated stack strategy. The renderer depends on neither facade.

The lower-level `Element.layout(_:children:)` factory and `ElementLayout` contracts are exposed by `TerminalUIEngine`:

- `LayoutProposal` represents the offered width/height.
- `LayoutSubview` supplies sizing preferences and synchronous measurement of an ordinary child.
- `ElementLayout.sizeThatFits` measures the container.
- `ElementLayout.placeSubviews` returns indexed child rectangles relative to its content origin.
- `ElementLayout.sizing` describes expansion propagated to its parent; custom layouts default to content sizing.

Subviews must not be retained outside a layout call. Strategies must be pure and must not mutate application state. The engine clips placements to the container, ignores invalid indices and uses only the first placement of each child. Layout children remain in the ordinary tree, so keyboard focus, modal scoping, pointer hit testing, scrolling and style inheritance continue through them.

Sizing preferences are cached per node. Proposal measurements retain up to eight entries per node; the existing width-measurement cache is unchanged. Content, explicit sizing and descendant changes invalidate measurements. Custom layout strategies are conservatively remeasured after a rebuilt application view. Theme changes invalidate measurements without rebuilding application content. Built-in viewport scrolling keeps the retained tree and skips painting unrelated siblings, including through negotiated containers.

This implementation provides deterministic integer-cell negotiation, not SwiftUI behavioral compatibility. Additional layout strategies can use the same contract without introducing another renderer or input system.

## Remaining scope

The negotiated row/column and composition scope is implemented. Additional layout features such as grid/flow strategies, layout priorities, adaptive breakpoint helpers and opt-in constraint diagnostics are future extensions. Existing controls are usable through both APIs; a layout feature does not require a second control implementation.

The earlier toolkit comparison also suggested multi-select lists, scheduled animation/spinners and an explicit unwrapped text viewer. Those are separate component/runtime features and have not been implemented by this layout work.

Validation: `swift test`, `python3 Scripts/test-terminalui-pty.py`, `python3 Scripts/test-terminalui-layout-pty.py`, and the LayoutDemo preview. The negotiated-layout tests cover builders, mixed APIs, bounded/weighted allocation, wrapping, resizing, growing input, axis-aware spacers, focus/pointer/modal routing, retained scrolling, alignment, small terminals and theme-dependent measurements.
