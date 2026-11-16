# Engine and custom controls

Use `TerminalUIEngine` when you need raw elements, an explicit terminal host or a custom widget. For declarative applications, start with [views and state](Components.md).

## A raw-element application

An engine application returns an `Element` tree and applies actions to its own values. The host manages terminal input, rendering, focus, caret position and scrolling.

```swift
import TerminalUIEngine

@MainActor
final class NotesApplication: TerminalApplication {
    let host = TerminalHost()
    var draft = ""

    func view() -> Element {
        .column(spacing: 1, [
            .panel(title: "Note", content: .textEditor(id: "draft", value: draft))
                .height(.fill()),
            .button("Quit", id: "quit")
        ])
    }

    func handle(_ action: UIAction) {
        switch action {
        case .textChanged("draft", let value):
            draft = value
        case .activated("quit"), .unhandledKey(.controlC):
            host.stop()
        default:
            break
        }
    }
}

@main
struct NotesMain {
    @MainActor
    static func main() async throws {
        let application = NotesApplication()
        try await application.host.run(application)
    }
}
```

Apply text and selection actions synchronously in `handle(_:)`. Call `host.invalidate()` when data changes outside an action. Keep `view()` free of side effects and inexpensive to rebuild.

Run `swift run EngineDemo` for a complete example; its [README](../Examples/EngineDemo/README.md) describes the controls.

## IDs, input and scrolling

Keep control IDs stable while they refer to the same content. The host retains focus, caret and viewport state by ID. Call `host.resetState(for:)` before reusing an ID for a different document.

- `host.focus(id, in: tree)` focuses an enabled, visible control.
- `.id("target")` identifies content for `host.keepVisible("target")`, which reveals it through enclosing scroll views.
- Tab and back-tab traverse controls. Dialogs trap focus; Escape emits a dismissal request.
- Editors insert newlines on Enter by default. With `.onSubmit("action")`, Enter emits that action and Shift+Enter inserts a newline when reported distinctly.
- Lists and tables emit selection changes as navigation moves. `.onSubmit("action")` adds Enter activation; `ListRow(activationID:)` supplies a row-specific action.
- Paste inserts text without activating controls. `.pasteTruncated` reports input exceeding the configured byte limit.

Scroll views support arrows, Page Up/Down, Home and End. They reveal focused children, clamp after resizing and optionally follow the end of content with `followsEnd: true`.

Tables use `TableColumn` and `TableRow`. Columns accept fixed widths, weighted fill or content width based on the header. Pass `bordered: true` for an outline and separators. Row IDs must be unique.

## Menus and shortcuts

Raw menus use `MenuItem` values and application-owned search and selection.

| Control | State to apply | Activation |
| --- | --- | --- |
| `.menuBar(id:items:selection:focusedItem:compact:)` | `.selectionChanged(barID, itemID)` updates the keyboard highlight. | `.activated(itemID)` |
| `.menu(id:title:items:query:selection:notice:)` | `.textChanged(id + ".search", value)` and `.selectionChanged(id + ".items", itemID)` | `.activated(itemID)` |

A menu bar's `selection` marks the current destination separately from `focusedItem`. Searchable menus filter titles; Escape emits `.dismissRequested(id)`, while their Return button emits `.activated(id + ".back")`. Close the overlay in response to either dismissal action.

Set `MenuItem.shortcut` for a local character shortcut and `globalShortcuts` for modified keys that work elsewhere in the active screen. A global shortcut emits an action; the application chooses whether to move focus. Dialogs restrict global shortcuts to their contents. Duplicate shortcuts take the first matching item; an unavailable match does not fall through.

`globalShortcuts` accepts Alt/Control printable ASCII characters (space through `~`) and `.controlC`, `.controlD`, `.controlP`. `.controlCharacter("c")`, `"d"` and `"p"` normalize to those dedicated events. Unsupported events fail a precondition when the `MenuItem` is initialized, with a message describing supported keys. Modified characters require distinct terminal reporting.

`.onKey(key, activate: id)` binds a key on the focused control. Paste, Tab traversal and dialog Escape retain their built-in meanings.

## Custom widgets and layouts

Implement [`CustomWidget`](../Sources/TerminalUICore/CustomWidget.swift) and wrap it with `Element.custom(...)`. The context-based methods provide:

| Method | Purpose |
| --- | --- |
| `measure(context:)` | Return the desired size in cells. |
| `draw(in:context:)` | Paint into the assigned clipped canvas. |
| `respond(to:context:)` | Handle a keyboard or mouse event. |
| `mouseTarget(at:context:)` | Return stable item IDs for matching pointer presses and releases. |

Responses are `.consumed`, `.unhandled` or `.action(...)`. Mouse coordinates are local to the widget's content canvas; contexts also supply focus, theme and assigned size.

For a custom layout, implement [`ElementLayout`](../Sources/TerminalUICore/ElementLayout.swift) and use `Element.layout(_:children:)`. It measures and places ordinary child elements, preserving their controls and interaction. Layout methods must be pure and must not retain the supplied subviews outside a call.

## Integrating with declarative views

Add the `TerminalUIBridge` product and import both APIs explicitly. Qualify overlapping names such as `Text` when needed.

```swift
import TerminalUI
import TerminalUIEngine
import TerminalUIBridge

@MainActor
func mixedContent() -> some TerminalView {
    TerminalUI.Column {
        EngineContent(Element.text("Custom engine content"))
        TerminalUI.Text("Declarative content")
    }
}
```

`ViewPresentation(root:)` adapts a declarative view to an engine-owned host. `engineElement(view)` embeds a declarative view in a raw tree. Resolve a presentation before passing its elements directly to a renderer.

## Styling and terminal capabilities

Pass a `Theme` to `TerminalHost`, or assign `host.theme` to change it while running. Raw elements support the same semantic roles, text spans and style modifiers described in [styling](Components.md#styling).

Colour detection uses `TERM`, `COLORTERM` and `NO_COLOR`. A nonempty `NO_COLOR` disables colour; `COLORTERM=truecolor` or `24bit` enables RGB, and `TERM` containing `256color` selects indexed colour. Override detection with `TerminalConfiguration(colorCapability:)`. An explicit override takes precedence over `NO_COLOR`. Enable `extendedAttributes` to emit dim and italic styles.

Mouse input is opt-in through `TerminalConfiguration(mouseEnabled: true)`. Primary clicks focus controls; buttons activate on a matching release. List and table clicks select rows, while wheel input scrolls the viewport under the pointer. Dialogs block background pointer input. Drag selection, double clicks, horizontal wheel and hover are not implemented.

The host requires a controlling TTY and rejects `TERM=dumb`. It restores terminal settings on normal exit, cancellation and handled termination signals. Unicode widths and modified key reporting depend on the emulator; Shift+Enter requires distinct terminal reporting. Job-control suspension and full bidirectional text layout are not implemented. Text measurement is limited to 100,000 graphemes and scrollable content to 4,096 rows.

## Rendering without a terminal

Use `UIEngine.render(_:width:height:)` for cell output and `InputDecoder.feedEvents` for ordered keyboard and mouse events. Render before dispatching mouse input so hit testing has current geometry, and render again after geometry changes. `TerminalHost` handles that ordering during interactive execution.

Built-in scrolling can repaint a viewport without rebuilding the application view. `UIEngine.handleEvent(_:in:)` distinguishes `.repaint` from `.rebuild(action:)` for callers managing rendering themselves.

See [architecture and development](Architecture.md) for package structure and validation commands.
