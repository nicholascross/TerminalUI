# TerminalUI

`TerminalUI` is a component toolkit and terminal host distributed as an independent Swift package. It has no dependency on the model or orchestration modules. Run commands from the TerminalUI package directory. Run the sample applications in a supported interactive terminal:

```sh
swift run RepositoryDemo
```

Compose an `Element` tree from application-owned values. `TerminalHost` acquires the controlling terminal, renders the tree, and dispatches keyboard input to the focused control. Apply actions synchronously in `handle(_:)` before the next view is drawn; call `invalidate()` for changes originating outside an action. The host retains the current tree: built-in scroll navigation with unchanged focus repaints the affected viewport without calling `view()` or reconciling layout. Unrelated screen content is retained. Enclosing scroll views and overlays repaint together to preserve clipping, focus reveal and compositing. Application actions, focus changes, resizing and explicit invalidation rebuild the view; custom-widget input also conservatively rebuilds, even when consumed without an action. Input batches rebuild as needed before dispatching the next event so it sees the latest application state. Keep legitimate `view()` calls inexpensive by caching application projections where appropriate. Stop the host when the application chooses to exit.

```swift
import TerminalUI

@MainActor
final class App: TerminalApplication {
    let host = TerminalHost()
    var draft = ""

    func view() -> Element {
        .column(spacing: 1, [
            .panel(title: "Note", content: .textEditor(id: "draft", value: draft))
                .height(.fill(weight: 1)),
            .button("Quit", id: "quit"),
            .statusBar("Tab: focus · Ctrl-C: quit")
        ])
    }

    func handle(_ action: UIAction) {
        switch action {
        case .textChanged("draft", let value): draft = value
        case .activated("quit"), .unhandledKey(.controlC): host.stop()
        default: break
        }
    }
}
```

See the demo entry point for calling `host.run(app)`. Text and list selection are controlled by the application; focus, caret and viewport are retained by the engine using stable IDs. Call `host.resetState(for:)` before reusing an ID for a different document. `host.focus(id, in: view)` requests focus for an enabled, visible control in the active tree; enclosing scroll views bring the focused control into view on the next render. The engine retains at most 256 inactive widget state entries. Identify non-focusable content with `.id("target")` and call `host.keepVisible("target")` to reveal it in enclosing scroll views on the next render. Tab and back-tab change focus; arrow keys navigate controls, including cursor keys reported with Caps Lock or Num Lock modifiers; Enter inserts a newline in a multiline editor or activates a focused button. For a submission box, append `.onSubmit("action-id")` to a text editor: Enter emits `.activated("action-id")` and Shift+Enter inserts a newline when the terminal reports that key distinctly. On terminals that do not support extended keyboard reporting, Shift+Enter may be indistinguishable from Enter; multiline paste remains available. Lists and tables also support `.onSubmit("action-id")`: Enter emits that action when the control is enabled and nonempty; selection alone does not submit. A dialog traps focus and Escape emits a dismissal request. Paste is data, not a button activation; `.pasteTruncated` reports a paste exceeding the configured byte limit.

Single-line text truncates with an ellipsis; use `paragraph` for wrapped text. Styled paragraphs accept `[TextSpan]` values with semantic roles. Text and stacks accept `.alignment(.leading)`, `.alignment(.center)` or `.alignment(.trailing)`. Aligned stacks use content or fixed cross-axis dimensions; fill occupies the available cross axis. Rows and columns also support content, fixed, and weighted fill sizes, padding, visibility and enabled state. Panels, paragraphs, lists, scroll views, fields, editors, buttons, dialogs, status text and custom widgets can be composed without terminal escape sequences. `UIEngine`, `Canvas` and `CellGrid` also permit deterministic rendering and testing without a TTY.

Scroll views allocate drawing storage for their viewport and clip offscreen content while preserving focus reveal and follow-end behavior. The engine retains intrinsic measurements for the active element tree, reusing them across rebuilt views until content or sizing inputs change. Each node remembers up to four proposed widths. Changes invalidate the affected node and its ancestors; custom widget measurements refresh when the tree is rebuilt because they can depend on live state or theme. Plain and styled paragraph wrapping is shared by measurement and drawing, with a cache that retains up to 4 MiB of estimated text and layout storage and 4096 entries across frames, evicting the least recently used layouts. Unchanged paragraph nodes reuse their cached wrapping directly without hashing the text again. Offscreen content remains eligible for reuse; nodes hold weak references so they cannot pin evicted layouts. Cache keys include text, span boundaries and available width. Only visible paragraph rows are painted. Span roles, overrides and theme styles are applied when drawing. Repainting retains the previous screen grid and skips unrelated branches of the tree during built-in scrolling. Initial rendering, changes to terminal dimensions, and view rebuilds paint a complete frame. Terminal output still compares complete visible grids and writes only changed cells; scrolling unchanged content does not require measuring the full document again. `UIEngine.handleEvent(_:in:)` returns `.repaint` for built-in scrolling with unchanged focus or `.rebuild(action:)` for input requiring a fresh application view; `handle(_:in:)` retains its action-only API.

`TerminalHostRenderingTests` checks view-call counts and cached measurements through the host's dispatch and paint path. `TerminalHostLatencyTests` reports median and p95 scroll input-to-output durations for a retained 500-entry document at 80×24 cells, including decoding, dispatch, painting, encoding and writes to a memory sink. It asserts zero additional `view()` calls and correct output, without timing thresholds that depend on the machine. These measurements exclude terminal I/O and scheduling.

Create a persistent horizontal menu with `.menuBar(id:items:selection:focusedItem:compact:)`, reusing `MenuItem` values. `selection` marks the current destination with `*`; `focusedItem` is the application-owned keyboard choice, marked with `>` when the bar has focus. Apply `.selectionChanged(barID, itemID)` to `focusedItem`. Left/Right and Home/End move that choice; Enter or Space emits `.activated(itemID)` for an available item. Item shortcut characters also activate while the bar is focused; global modifier shortcuts are opt-in through `MenuItem.globalShortcuts`. Unavailable items are dimmed and remain selectable for prerequisite inspection, but Enter does not activate them. Shortcut activation emits the item ID so the application can explain an unavailable destination. Paste never activates an entry. Compact mode removes the space between shortcut and title; applications supply abbreviated titles where needed. The bar keeps the focused/current item visible if its contents exceed the available width.

Declare global menu shortcuts on items when they should work while another control has focus:

```swift
.menuBar(id: "navigation", items: [
    MenuItem(id: "files", title: "Files", shortcut: "1",
             globalShortcuts: [.altCharacter("1"), .controlCharacter("1")])
], selection: "files")
```

Alt+1 or a distinctly reported Control+1 emits `.activated("files")`; the application can then call `host.focus` or switch screens. `shortcut` remains a character shortcut used only while the menu has focus. Global shortcuts support `.altCharacter`, `.controlCharacter` and the dedicated `.controlC`, `.controlD`, `.controlP` cases. Other key types in `globalShortcuts` are ignored, preserving typing, paste, traversal and Escape. Shortcuts do not move focus themselves. They take priority over focused-control key bindings; duplicate bindings use the first matching item in tree order. A matching unavailable item consumes the key without activation or fallthrough. Hidden/disabled menus and their descendants do not register global shortcuts.

An open dialog scopes global matching to that dialog, blocking workspace menu shortcuts. A searchable `.menu` registers only its currently matching results, including when the search field has focus. Existing focused character shortcuts retain their unavailable-item inspection behavior. Global shortcuts are empty by default, so existing applications retain their shortcut handling.

Create a searchable modal menu with `.menu(id:title:items:query:selection:notice:)` and `MenuItem(id:title:shortcut:unavailableReason:)` values. The menu composes a dialog, search field and list; query and selection remain application-owned. Apply `.textChanged("menu.search", value)` and `.selectionChanged("menu.items", itemID)` when using `id: "menu"`. Search filters titles without case sensitivity and falls back to the first match if the selected item no longer matches. Enter emits `.activated(itemID)` for an available selection. Down moves focus from search into the results, where the usual list navigation applies. Character shortcuts apply in search and results only when the query is empty; paste remains search text. A shortcut emits the item ID even when unavailable, allowing the application to explain its prerequisite. Unavailable items remain selectable and show their reason, but Enter cannot activate them. No matches displays an empty-state message. Escape emits `.dismissRequested("menu")`; Return emits `.activated("menu.back")`. The application closes the overlay for either action, and the engine restores prior focus. Applications own destination behavior and any shortcuts not declared on menu items.

The separate `TerminalUIChroma` product converts [Chroma](https://github.com/onevcat/Chroma) syntax tokens to semantic text spans, so the active TerminalUI theme and terminal colour settings control their appearance. Add the product to your target and use it as follows:

```swift
import TerminalUI
import TerminalUIChroma

let highlighter = SyntaxHighlighter()
let spans = try highlighter.spans("let answer = 42", language: "swift")
let view = Element.paragraph(spans)
```

Pass a Chroma language identifier, such as `swift`, `python`, or `markdown`; a nil language returns plain spans and an unknown language throws. Keywords, types, functions and properties (including JSON keys) use the theme's `syntaxKeyword`, `syntaxType`, `syntaxFunction` and `syntaxProperty` styles, which applications can customize. Chroma's language rules determine which identifiers receive those classifications; it does not perform semantic type analysis. Markdown is syntax-highlighted, including recognized fenced code, rather than laid out as formatted Markdown. Paragraph wrapping and whitespace handling still apply. The package requires macOS 13 or later, matching Chroma's minimum deployment target. RepositoryDemo uses the integration in its Syntax view with Swift, Python and JSON examples.

Scroll views respond to arrows, Page Up/Down, Home and End; they keep a focused child visible and clamp their position after resizing. Focus moves to the next surviving control when the focused control disappears, and returns to the previous control after a dialog closes when possible. Pasted CRLF and CR line endings become newlines in editors and spaces in fields. Pass a `Theme` to `TerminalHost` to customize semantic styles. Custom widgets can use measurement, draw, and event contexts with the available width, assigned canvas size, focus and theme. They return `.consumed`, `.unhandled`, or `.action` from event handling. The earlier themed methods remain available.

`KeyEvent.altCharacter` and `.controlCharacter` represent modified printable ASCII keys; Control-C/D/P retain their dedicated cases. The decoder accepts legacy Escape-prefixed Alt keys where they do not collide with control-sequence prefixes, and Alt/Control keys in CSI-u and modifyOtherKeys encodings, including keyboard lock flags. It does not infer ambiguous legacy Ctrl-number combinations. Standalone Escape retains the configured timeout; a later digit after that timeout is ordinary text. Modified character events reach the application as unhandled keys from built-in editors without changing their text, caret or selection. Terminal/desktop shortcut interception still requires validation in the target environment.

Use `.onKey(.character("3"), activate: "activity")` to bind a key on a focused control, such as numbered choices in an empty menu search. The engine emits `.activated("activity")` instead of the control's usual response for that key. Only the active, enabled, focused control's bindings apply; Tab traversal and dialog Escape retain their built-in handling. Bracketed paste remains a separate event and does not activate a character binding. Applications own destination meanings; menu global shortcuts use the active dialog scope described above.

The host requires a controlling TTY and rejects `TERM=dumb`. It temporarily installs process-wide signal handlers and uses raw terminal settings, an alternate screen, bracketed paste and a hidden cursor; it restores saved settings on ordinary exit, cancellation and handled termination signals. Forced termination and process crashes cannot guarantee restoration; `stty sane` and `reset` can recover a damaged shell. `NO_COLOR` disables ANSI colors. The host requests extended keyboard reporting to distinguish Shift+Enter where supported. Job-control suspension and full bidirectional layout are not implemented.

Enable mouse input with `TerminalHost(configuration: TerminalConfiguration(mouseEnabled: true))`. It defaults to disabled to preserve terminal text selection. RepositoryDemo enables mouse input by default; use `swift run RepositoryDemo --no-mouse` to preserve terminal text selection. The host requests normal button tracking with SGR cell coordinates and disables those modes during cleanup. Actual emulator and multiplexer behavior still requires validation in the target terminal.

Primary presses focus controls. Buttons and available menu items activate once on a matching release over the same visible target; releasing elsewhere cancels activation. Menu results select on press and activate the clicked row on release. Disabled rows remain selectable for inspection but cannot activate. Ordinary list and table clicks select without submitting; Enter retains submission behavior. `ListRow(activationID:)` opts a row into its own Enter/click action, taking precedence over a list-level `.onSubmit`. Tabs select on press. Panel title, border and empty-background clicks keep an already focused descendant, or focus the first enabled descendant. Panels have no separate window focus state. Dialogs trap mouse input as well as keyboard focus; outside clicks do not dismiss them.

Fields and editors place the caret at the nearest displayed grapheme boundary and clear text selection on a primary press. Wheel input scrolls the deepest enabled viewport under the pointer by up to three rows per report, without changing keyboard focus, selected rows or the caret. Nested scrolling falls back to an enclosing viewport at a boundary. A manual scroll may hide focused content; keyboard interaction, programmatic focus and `keepVisible` reveal it again. Scrolling to the bottom resumes `followsEnd`. Horizontal wheel gestures, drag selection, double clicks and continuous hover effects are not implemented.

For terminal-independent input, use `InputDecoder.feedEvents` to receive ordered `TerminalEvent.key` and `.mouse` values; `feed` keeps its keyboard-only contract and consumes mouse packets without returning them. `MouseEvent` uses zero-based cells and records press/release or vertical wheel direction, button and modifiers. Render the current tree before calling `UIEngine.handleMouseEvent`; refresh rendering after geometry-changing input. Without current geometry, mouse input is ignored. `TerminalHost` refreshes geometry as needed between events in a batch, while retaining application views for built-in wheel scrolling.

Custom widgets can implement `respond(to: MouseEvent, context: WidgetMouseContext)` using local cell coordinates and the assigned size, focus and theme. The default is `.unhandled`. `mouseTarget(at:context:)` defaults to the widget ID; return stable item IDs for independent press/release targets, or nil for noninteractive cells. The engine enforces clipping, enabled state and matching primary releases. The [original investigation](Documentation/Specs/TerminalUI/Mouse-Support-Investigation.md) records the design reasoning.

Rendering and measurement are bounded to the first 100,000 graphemes of a text value. Scrollable content is limited to 4,096 rows. Shift-arrow keys extend editor selection when the terminal reports them.

The editor retains its viewport as the caret moves and handles clipped wide characters; Unicode and wrapping behavior still needs validation in real terminals. Output coalesces changed cell runs and redraws complete wide-character footprints. Terminal failure recovery and teardown have not been verified across the full target platform matrix. The repository demo stacks its panes in narrow terminals; not all specified responsive workflows have been validated. Rich Markdown, job control and full bidirectional layout remain deferred.

Unicode cell widths vary by emulator. The width policy is conservative and should be checked in the target terminal, especially for emoji and mixed-direction text. Linux PTY lifecycle, keyboard and mouse interaction checks are available through `python3 Scripts/test-terminalui-pty.py` after running `swift build` to build the demo. This does not replace validation in macOS Terminal, Foot, tmux or other real environments. The [design specification](Documentation/Specs/TerminalUI/TerminalUI-Swift-Package-Design-v2.md) includes future work and validation targets beyond the implementation.

The [internal architecture](Documentation/Architecture.md) describes the SwiftPM targets and dependency composition. The [module migration review](Documentation/Module-Migration-Review.md) records the public type ownership changes; existing source imports and qualified names remain available through the `TerminalUI` facade.

## Optional negotiated layout

The `TerminalUILayout` product adds closure-based composition and negotiated sizing while using the same elements, controls and terminal host:

```swift
import TerminalUILayout

let view = Column(spacing: 1) {
    Text("Workspace").role(.heading)
    Panel("Files") {
        List(id: "files", rows: fileRows, selection: selectedFile)
    }
    Panel("Command") {
        TextEditor(id: "command", value: draft)
    }.height(.fit(maximum: 8))
    StatusBar("Tab: focus · Ctrl-C: quit")
}
```

The files panel takes remaining height; the heading, composer and status bar request their own sizes. Builders support conditionals, loops, arrays and ordinary functions returning `Element`. Existing array-based row/column APIs retain their sizing behavior and compose with the new containers. See [negotiated layout](Documentation/Negotiated-Layout.md) for preferences, sizing rules and custom layouts. Run `swift run LayoutDemo` or `swift run LayoutDemo --preview`.

The optional `TerminalUIComponents` product adds declarative applications with `@main @TerminalApplication`, mounted struct views, `@TerminalComponent`, `@State`, `@Binding`, bound controls and scheduled selective updates. Declare the root screen and optional theme/configuration; the framework assembles the host and presentation. Mounted screens access focus and shutdown through `@ApplicationContext`. LayoutDemo uses this layer with a dedicated `LayoutViewModel`, shared bindings and an independent command draft. See [components and mounted state](Documentation/Components.md) for compiled examples, application setup, identity rules, transactions, mixed migration and scoped focus.


## Styling and terminal capabilities

`Theme.terminalNative` uses terminal-default text and background where practical; `Theme.dark` and `Theme.light` supply foreground palettes intended for dark and light terminal backgrounds respectively. `Theme.dusk()` supplies the Parallax harness palette directly: an opaque dark background, layered surfaces, violet accents, tinted badges and rounded borders. It detects colour capability by default; pass `Theme.dusk(colorCapability: .ansi16)` when the host uses an explicit override. Its ANSI variant uses neutral named backgrounds to avoid mapping dark surfaces to bright colours in customised terminal palettes. Select a theme with `TerminalHost(theme:)`, or assign `host.theme` at runtime to redraw. A theme is a value: copy a built-in and change its semantic properties, for example:

```swift
var theme = Theme.dark
theme.warning = TextStyle(foreground: .rgb(255, 190, 80), bold: true)
let host = TerminalHost(theme: theme)
let label = Element.text("Warning: unsaved").role(.warning).underline()
let content = Element.column([
    label,
    .text("Details").foreground(.default),
    .paragraph([TextSpan("Status: "), TextSpan("ready", role: .success)])
]).foreground(.cyan)
```

The harness appearance uses public styling APIs, with no custom renderer required:

```swift
let theme = Theme.dusk()
let host = TerminalHost(theme: theme)
let workspace = Element.panel(title: "Repository", content: .column(spacing: 1, [
    .text("Working tree").role(.heading),
    .textField(id: "filter", value: "", placeholder: "Filter files")
        .background(theme.field.background),
    .text("Ready to inspect").role(.success)
]).padding(.init(leading: 1, trailing: 1)))
    .background(theme.surface.background)
```

Roles include primary (`normal`), `secondary`, `muted`, `heading`, `accent`, `highlighted`, `info`, `success`, `warning`, `error`, `border`, `activeBorder`, `surface`, `field`, `cursor`, `dialog`, `action`, `focused`, `selection`, and `disabled`. Built-ins use the relevant roles for their presentation; applications and custom widgets can use any role. Focus and selection also use markers, and disabled buttons have a textual label. `ListRow(id:title:isEnabled:)` defaults to enabled; disabled rows use the disabled style and a leading `[disabled]` label, including when selected. They remain selectable for inspection but Enter does not emit the list's submit action. There is no persistent pressed state or built-in validation model; use an error role and explanatory text for validation.

Styles have foreground, background, bold, dim, italic, underline and reverse properties. Colours include terminal default, standard and bright ANSI colours, `.indexed(UInt8)` and `.rgb(UInt8, UInt8, UInt8)`. `style(StyleOverride(...))` or the `foreground`, `background`, `bold`, `dim`, `italic` and `underline` modifiers override individual properties. An omitted property inherits; `.default` explicitly requests the terminal default. Container overrides are inherited by descendants; an explicit `.background(...)` also fills the container’s empty cells. Resolution starts with the element's semantic role, applies inherited properties, replaces that style with a focused, selected or disabled state style when applicable, then applies local overrides. Explicit local overrides can therefore deliberately override state styling. Rich paragraph spans apply their own role and overrides last and retain them across wrapping. Custom widgets receive `context.theme`, `context.style`, and `context.enabled`; they can use these with their canvas.

The host detects colour from `TERM`, `COLORTERM` and `NO_COLOR`. The [NO_COLOR convention](https://no-color.org/) suppresses colour when the variable is nonempty but retains supported emphasis. `COLORTERM=truecolor` or `24bit` selects RGB; `TERM` containing `256color` selects the indexed palette; other nonempty, non-dumb terminals use 16 colours. The host requires a controlling terminal and rejects `TERM=dumb`. RGB and indexed values are mapped to the nearest available fixed xterm palette when needed; a user's customised ANSI palette can change the result. Detection cannot verify multiplexer passthrough. Override it with `TerminalConfiguration(colorCapability: .trueColor)` or restrict it with `.indexed256`, `.ansi16`, or `.none`; an explicit override takes precedence over `NO_COLOR`. Bold, underline and reverse are emitted by default; set `extendedAttributes: true` to opt into dim and italic when the terminal supports them. This is a conservative policy, not terminal feature probing.

Run `swift run RepositoryDemo` for a read-only Git browser of the current repository, or `swift run RepositoryDemo --repo /path/to/repository` to open another one. Git must be available on PATH. The browser runs status, diff, log and show queries with optional Git locks disabled. It never stages files, creates commits or checks out branches. The Files list shows Git's two status columns (index and working tree), including untracked files. Select a file to view its working-tree diff; Staged diff shows its index changes. Untracked files display a notice rather than a diff. Branch selection shows that branch's recent history without switching branches. The Commits table shows the latest 50 commits on HEAD; clicking one or pressing Enter opens its full message, author, dates, changed-file statistics and patch in the Commit tab. Newer and Older step through the loaded history, and the Commit tab or “View selected commit” command reopens the selection. Clean repositories open the latest commit initially; repositories without commits show an explicit empty state. Refresh reloads changes made outside the browser. Empty repositories, clean working trees and detached HEAD are supported; Git errors appear in the status bar.

Alt+1–4 focuses Files, Branches, Commits and the Inspect tab strip respectively. In Inspect, Left/Right switches Git output, Syntax, Components and Commit; Tab enters the selected view’s controls and Shift+Tab returns to the strip from its first control. Control+1–4 also works when reported distinctly by the terminal. Pane shortcuts preserve sample drafts and selections and stay inactive while a dialog is open. Ctrl-P opens searchable read-only commands. Escape closes overlays and Ctrl-C exits.

The demo opens with Dusk, using layered panel backgrounds, padded content, tinted badges and rounded borders. Theme remains in the menu bar and cycles Dusk, dark, light and terminal-native palettes. Samples opens the Components gallery, with editing controls, nested scroll views, disabled controls, Unicode text, semantic styles and progress. Its editable fields are in-memory examples and do not write to repository files. Syntax retains Swift, Python and JSON highlighting examples. Use `--mono`, `--16`, `--256` or `--truecolor` to inspect colour fallbacks, and `--extended-attributes` for dim and italic. Dark and light use foreground palettes and need matching terminal backgrounds; Dusk paints its own background.

Run `swift test` for engine, decoder, host, component and Git query tests, then `python3 Scripts/test-terminalui-pty.py` for the running demo. Git tests and PTY checks use temporary repositories and verify that browsing preserves the index, working files and checked-out branch. PTY checks cover read-only diffs, branch and commit inspection, refresh, pane navigation, theme and syntax samples, wheel routing, nested scrolling, editor caret placement and paste, dialogs, resizing, mouse opt-out and terminal cleanup. The unit tests additionally cover clipped targets, wide characters, input packet boundaries, modifiers, stale geometry and follow-end scrolling. These checks do not establish compatibility with a particular emulator or multiplexer. Drag selection, double-click, horizontal wheel and hover remain unimplemented.

Tables display a persistent header and a vertically scrolling selection. Construct one with `.table(id:columns:rows:selection:)`, using `TableColumn("Name", width: .fill())` and `TableRow(id: "one", cells: ["First"])`. Columns accept `.fixed` cell widths, weighted `.fill`, or `.content` (the header width). Fixed and content columns are allocated first; remaining space is shared by fill columns, with a single space between columns. Narrow tables clip later columns and truncate cell text with an ellipsis. Missing cells are blank and extra cells are ignored. Row IDs must be unique. The application applies `.selectionChanged` to its selection; Up/Down, Page Up/Down, Home and End navigate, and the engine keeps the selected row visible as the table resizes or rows change. The header occupies one row. Pass `bordered: true` to add an outline, column dividers and a header separator; the outline and separator occupy three more rows and two more columns. Any remaining height displays data. Reset the ID with `resetState(for:)` when reusing it for another table. RepositoryDemo uses an interactive table for its commit history.
