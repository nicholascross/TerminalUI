# Views, state and focus

Use `import TerminalUI` to build applications from reusable views. For arranging and sizing those views, see [layout and sizing](Layout.md).

## Applications

Declare an application with `@main` and `@TerminalApplication`. Its `root` is the screen to display; `theme` and `configuration` are optional.

```swift
import TerminalUI

@main
@TerminalApplication
struct NotesApp {
    var root: some TerminalView { Workspace() }
    var theme: Theme { .nord() }
    var configuration: TerminalConfiguration { .init(mouseEnabled: true) }
}
```

A plain application must be constructible without arguments. For command-line inputs, use the optional [argument integration](Arguments.md).

Mouse input defaults to disabled for plain applications, preserving normal terminal text selection. Enable it through `configuration` when the screen needs clicks and wheel scrolling.

With `TerminalConfiguration(mouseEnabled: true, copyOnSelect: true)`, apply `.textSelection()` to the `Text` and `Paragraph` views that should support dragging to copy. The modifier applies to each text view individually, including when it sits inside a panel or scroll view.

## State and bindings

A view describes its content with `body: some TerminalView`. Use `@TerminalComponent` on views that own `@State` or access `@ApplicationContext`.

```swift
@TerminalComponent
struct Workspace: TerminalView {
    @State private var draft = ""
    @ApplicationContext private var application

    var body: some TerminalView {
        Column(spacing: 1) {
            DraftEditor(text: $draft)
            Paragraph(draft.isEmpty ? "Start writing a note." : draft)
            Button("Quit").onActivate { application.stop() }
        }
    }
}

struct DraftEditor: TerminalView {
    @Binding var text: String

    var body: some TerminalView {
        Panel("Draft") {
            TextEditor(id: "draft", text: $text)
                .initialFocus()
        }
        .height(.fit(maximum: 8))
    }
}
```

`@State` keeps a value across view updates. Passing its projected value, such as `$draft`, creates a binding: edits in the child update the owner's state and any views displaying it.

Text fields, editors, lists, tables, tabs and menus accept bindings. Use `Binding(get:set:)` to transform or validate edits, `Binding.constant(...)` for a fixed value, and projections such as `$model.title` for a property of a stored value.

State assignments are synchronous; rendering updates are scheduled automatically. Mutate state in event callbacks, keeping view bodies free of side effects. Reference objects stored in state are not automatically observed: replace the stored value or call `invalidate()` on a `TerminalApp` when their contents change.

## Controls and callbacks

| Control | Common use |
| --- | --- |
| `Text`, `Paragraph` | Single-line labels and wrapped text. |
| `TextField`, `TextEditor` | Single-line and multiline input. |
| `List`, `Table` | Selectable rows, with optional submission actions. |
| `Tabs`, `MenuBar` | Persistent choices and pane navigation. |
| `Menu`, `Dialog` | Searchable commands and modal content. |
| `Button`, `Progress`, `StatusBar` | Actions, progress and status. |

Attach `.onActivate { ... }` to buttons and `.onSubmit { ... }` to input or collection controls. An editor with a submit handler uses Enter to submit and Shift+Enter for a newline when the terminal distinguishes those keys. Multiline paste inserts text without submitting.

Buttons need an explicit `id:` only when you need to look them up or address a named action. Add a modified shortcut with `.keyboardShortcut(.controlP)` to activate a button from elsewhere in the active screen or dialog.

Button shortcuts accept `.altCharacter(...)` and `.controlCharacter(...)` with printable ASCII (space through `~`), plus `.controlC`, `.controlD` and `.controlP`. The character forms for Control-c/d/p are aliases for those dedicated events. Unsupported declarations, including plain characters, Enter, Tab, Escape, paste and modified Unicode characters, fail a precondition with an explanatory message. Modified character shortcuts require distinct reporting from the terminal.

`List` and `Table` manage selection locally when you omit `selection:`. Pass a binding when another view needs the selected value. `initialSelection:` seeds local selection when the control first appears.

## Menus and pane navigation

Give each destination a typed value and register it on its control with `.focusTarget(...)`. A `MenuBar` or `Menu` can then navigate to those destinations automatically.

```swift
enum Pane: String, CaseIterable, MenuItemDefinition {
    case notes, editor
    var id: Self { self }
    var title: String { self == .notes ? "Notes" : "Editor" }
}

@TerminalComponent
struct NavigationWorkspace: TerminalView {
    @State private var draft = ""
    @State private var commandsOpen = false
    @ApplicationContext private var application

    var body: some TerminalView {
        Column(spacing: 1) {
            MenuBar(
                id: "navigation", items: Pane.allCases,
                activeItem: application.focusedValue(of: Pane.self)
            )
            Button("Commands")
                .onActivate { commandsOpen = true }
                .keyboardShortcut(.controlP)
            List(id: "notes", rows: [
                ListRow(id: "welcome", title: "Welcome")
            ])
            .focusTarget(Pane.notes)
            .initialFocus()
            TextEditor(id: "draft", text: $draft)
                .focusTarget(Pane.editor)
        }
        .overlay {
            if commandsOpen {
                Menu(id: "commands", title: "Go to", items: Pane.allCases)
                    .onActivate { commandsOpen = false }
                    .onDismiss { commandsOpen = false }
            }
        }
    }
}
```

`activeItem` marks the actual destination independently of the menu bar's keyboard highlight. Read it from `application.focusedValue(of:)`, which updates when focus changes through the keyboard, mouse or application code.

Menu entries receive numbered access keys for positions 1–9. Menu bars also accept Alt/Control variants of printable ASCII access keys when the terminal reports them distinctly. Override an item's `menuShortcut` with `.key(...)` or `.none` where needed. Both menu bars and searchable menus accept Unicode local access keys; menu bars activate them while focused, and searchable menus use them only while the query is empty. Unicode access keys do not generate global variants.

A `Menu` keeps its search and highlighted result locally. Removing the conditional menu resets them; reopening starts a new search. `.onDismiss` handles both Escape and the built-in Return button.

The menu's `.onActivate` observer runs before its navigation action. Dismiss the modal there so focus can move to a background pane. Supply an `onActivate:` initializer closure for an item action that replaces default navigation, such as saving or refreshing.

For existing identifiable models, supply `itemTitle:` instead of conforming to `MenuItemDefinition`. Use `unavailableReason:` to show an entry that can be inspected but cannot be activated.

## Focus and reveal

Apply `.initialFocus()` to the control that should receive focus when a screen or dialog opens. Later updates preserve the user's focus. Dialogs restrict focus to their contents and restore the previous control when dismissed.

Call `application.focus(Pane.editor)` to move to a registered destination. Hidden and disabled controls cannot receive focus, and an open dialog blocks requests to background controls. Use `.onFocusChange(of: Pane.self) { ... }` for effects such as changing a status message.

For repeated workspaces, apply `.scope("left")` and resolve it with `application.scope("left")`. Pass the resulting scope to `focus(_:in:)` to distinguish otherwise identical destinations. Ambiguous lookups fail.

Use `.id(value)` on a view, then `application.reveal(value)`, to bring content into view through its enclosing scroll containers. Reveal preserves state. For direct control lookup, `focusTarget(path:id:)` follows view IDs and `ForEach` item IDs; `id:` is the final control's local ID. Focus handles and scopes belong to the current view lifetime.

## Collections and view lifetime

Use `ForEach(items, id: \.id)` when insertions and reordering should preserve each item's local state. IDs must be unique within that collection. Ordinary `for` loops use position instead.

Changing a view's `.id(value)` resets the state of that view and its descendants. View IDs also support reveal and focus paths; they are separate from a control's `id:` argument.

Removing a conditional view discards its local state; showing it again starts fresh. Separate conditional branches have separate lifetimes, even when they contain the same view type. Use `.visible(false)` when you want to hide content while retaining its state.

For layouts that change direction, use `Stack(axis:)` to preserve child state and focus across the change. See [responsive layouts](Layout.md#responsive-layouts).

## Styling

Select a `Theme` at the application level and use roles such as `.heading`, `.secondary`, `.success` and `.error` on content. The built-in themes include terminal-native, dark and light defaults, plus named presets such as Nord and Dracula.

Apply `.foreground(...)`, `.background(...)`, `.bold()`, `.underline()` or `.style(...)` for local overrides. Container styles pass to descendants, and an explicit background also fills empty cells.

`Paragraph` accepts `[TextSpan]` for styled runs. The optional `TerminalUIChroma` product produces these spans from source code:

```swift
import TerminalUI
import TerminalUIChroma

@MainActor
func highlightedSource(_ source: String) throws -> some TerminalView {
    let spans = try SyntaxHighlighter().spans(source, language: "swift")
    return Paragraph(spans)
}
```

Highlighting supplies token colours, including for Markdown source; it does not render formatted Markdown.

See the [layout demo](../Examples/LayoutDemo/README.md) for shared bindings and navigation, or [application testing](Architecture.md#application-testing) to exercise your views without a terminal.
