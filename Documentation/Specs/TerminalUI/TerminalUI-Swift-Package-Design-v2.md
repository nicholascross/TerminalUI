# TerminalUI: Cross-Platform Swift Package — Revised Component Toolkit Design

**Status:** Revised architecture (v2), not a completed API or compiled implementation  
**Research date:** 31 October 2026  
**Platforms:** macOS and Omarchy Linux (Swift 6, native terminal application)  
**Package/product:** `TerminalUI` (provisional)  
**Design client:** Parallax, with no package dependency on Parallax  
**Change from v1:** Common, composable UI elements and widgets are first-class requirements, not deferred conveniences.

**Parallax scope note (7 November 2026):** Product examples below reflect the earlier harness design. They demonstrate toolkit composition, not a requirement to restore worksheet acceptance, Direct or removed application screens. The Parallax contributor guide in the ModelCommunication repository identifies the governing product documents. TerminalUI remains independent of those application policies.

---

## 1. Executive decision — component-first public API, terminal-first internals

The earlier design correctly identified the difficult terminal plumbing but **made the wrong public-API decision**: leaving application authors to calculate rectangles, render text and route individual keys. That would make every new screen expensive to build and would duplicate focus, scrolling, editing and selection behaviour throughout Parallax.

**Corrected recommendation:** a single independent SwiftPM package, `TerminalUI`, with a small **composable UI element model and useful built-in widgets**. Ordinary application code describes an element tree; the library measures it, lays it out, dispatches input, manages transient widget state, paints into a cell buffer and emits terminal control sequences. The lower-level `Canvas` remains an extension mechanism, not the default application interface.

The model is deliberately between two extremes:

- **Too low-level (rejected):** `render(&Canvas)` and an application-wide raw-key handler for every screen.
- **Too broad (also rejected):** a terminal clone of SwiftUI with implicit property wrappers, general animation, CSS, arbitrary effects, dependency injection and a sophisticated reconciliation engine.
- **Chosen:** an **explicit value-based element tree**, a constrained stack/flex layout, reusable widgets, stable IDs for interactive elements, managed ephemeral interaction state, and application-owned business state with typed UI actions.

**Package contract:** a developer should be able to build a notes editor, task browser or Parallax-style worksheet screen using components without writing cursor-positioning code, rectangle math, raw event decoding or manual focus logic. Implementing unusual controls should still be possible through a custom-widget protocol.

| Decision | Choice | Why |
|---|---|---|
| Public programming model | Composable `Element` tree rebuilt from current app state | Concise screen definitions and predictable updates |
| Built-in components | Text, rich text, panels, rows/columns, scroll regions, selectable lists, inputs, buttons, dialogs, status/help strips | Covers everyday development rather than requiring custom drawing |
| Layout | Two-pass intrinsic/fixed/flex measurement; clipping and bounded stack layout | Handles variable terminal sizes with little boilerplate |
| Input | Focus manager dispatches to widgets, then emits application actions | Editors/lists/dialogs work consistently |
| Widget lifetime | Value descriptions each render; UI-local state keyed by stable `ElementID` | No long-lived heavyweight widget objects or lost caret positions |
| Business state | Owned by consumer; changes arrive through `UIAction` | No Parallax concepts or model/tool dependencies |
| Rendering | Element tree → layout → `Canvas` → `CellGrid` → terminal diff | Reuses the original low-level engine internally |
| Cross-platform | Swift 6; Darwin/Glibc POSIX transport; macOS 13+ and Omarchy glibc Linux | No native desktop-framework dependency |
| Other libraries | Architectural references only; no runtime dependency on existing TUI frameworks | A focused, project-owned implementation |

### Usability threshold

The **ordinary path** must require fewer than a dozen lines of view construction for a panel containing wrapped text, a selectable list and an editable input. Users should not need to implement Tab traversal, list-arrow navigation, editor cursor movement, clipping or terminal resizing. A custom widget is an advanced extension, not a prerequisite to normal screen development.

### The two non-negotiable boundaries

1. `TerminalUI` owns how widgets respond and draw; the **consumer owns what an action means**. A button activation does not itself approve, persist, interrupt or execute anything.
2. `TerminalUI` owns transient focus, scroll and editor-caret state; the **consumer owns meaningful values**, such as draft text, selected evidence and currently visible worksheet. An explicit API resets UI-local state when switching identities or document revisions.

## 2. Scope, ownership and the Parallax design input

### 2.1 What the package provides

1. The terminal session: raw/noncanonical mode, TTY acquisition, signal/resize handling, optional protocols and reliable cleanup.
2. Input decoding and text safety: UTF-8, escape sequences, bracketed paste, terminal capabilities, grapheme and display-cell width.
3. Rendering: styles, clipped canvas, cell grid, frame diff, bounded nonblocking output.
4. **Elements and composition:** stack layout, panels, padding, flex sizing, scroll views, overlays and theme tokens.
5. **Widgets and interaction:** paragraphs, labelled content, lists, single- and multi-line editing, buttons, confirmation dialogs, keyboard help, selection, focus and traversal.
6. **Application hosting:** map decoded terminal events to widgets and send meaningful `UIAction` values to application code; coalesce redraws from asynchronous changes.
7. Unit, snapshot, property, PTY and interaction testing support independent of any app.

### 2.2 What remains outside the package

Parallax's worksheet, evidence provenance, task execution, revision acceptance, model calls, application persistence, security approvals, domain commands and business navigation. `TerminalUI` must not import Parallax, ModelCommunication, SwiftUI, AppKit, Wayland, ncurses or an existing TUI widget framework.

The library may have generic **presentation** components called `Dialog`, `List` and `StatusBar`. It must not have application-specific `WorksheetView`, `InterrogationView`, `ApprovalPolicy` or `AgentStatus`. Parallax builds those as compositions of generic elements.

### 2.3 Why Parallax is a useful design client

| Parallax activity | Everyday UI abstraction required |
|---|---|
| Read a concise worksheet | `Panel` + wrapped `Paragraph` + `ScrollView` |
| Interrogate in natural language | `TextEditor` + `Button` + standard keyboard navigation |
| Inspect evidence | `List` with selection, detail `Panel`, responsive `Row`/`Column` |
| Review a proposed revision | Two `ScrollView`s or custom diff widget inside a `Panel` |
| Explicitly approve a direction | Focus-trapped `Dialog` + explicit button activation |
| Watch task activity unobtrusively | `StatusBar` and semantic `Text` styles |
| Use narrow terminals or SSH | Flex layout, minimum widths, reflow, keyboard-only focus |

The library should pass a **second independent application test**: a NotesDemo can implement a multi-line text editor, list of notes and confirmation dialog using only the public element/widget APIs. This is an API design requirement, not decorative sample code.

### 2.4 Vertical boundaries

```text
Application state and async work (Parallax, NotesDemo, etc.)
             │ view()                    ▲ handle(UIAction)
             ▼                           │
       UI ELEMENT / WIDGET LAYER ────────┘
       composition / focus / editor / state
             │ measure / layout / paint
             ▼
       RENDERING AND TEXT LAYER
       cells / Unicode / clipping / frame diff
             │ encoded bytes             ▲ key/paste/resize
             ▼                           │
       TERMINAL PLATFORM LAYER ──────────┘
       Darwin or Glibc / PTY / termios / signals
```

A developer should normally touch only the top boundary.

## 3. Research findings and compatibility baseline

This section separates established protocol/platform findings from judgments made for the package.

### 3.1 Platform and emulator matrix

The current [Omarchy terminal manual](https://omarchy.org/manual/terminal/) names **Foot** as the default terminal, with Alacritty, Ghostty and Kitty offered as supported alternatives. An older Omarchy manual describes Alacritty as the default: the default changed across releases, so **never infer the running emulator just from the Linux distribution**. The [Omarchy terminal selection script](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-default-terminal) also explicitly recognises those four emulators.

| Environment | Priority | Expected baseline | Needs real validation |
|---|---|---|---|
| macOS Terminal.app | P0 | VT/xterm-style navigation, colour, paste, alternate screen | Width, colour, keyboard quirks and restore |
| macOS Ghostty | P0 | Same baseline; modern optional keyboard support | Negotiation, wide glyphs, resize |
| Omarchy Foot | P0 | Same baseline; Wayland terminal is irrelevant to TUI code | Primary Linux interactive tests |
| Omarchy Alacritty | P1 | Same baseline; extended input may vary by version | Keyboard and colour feature checks |
| Omarchy Ghostty / Kitty | P1 | Same baseline; optional richer input | Key protocol push/pop, paste, emoji |
| tmux on either OS | P0 | `TERM` identifies tmux's virtual terminal | Alternate screen, resize, key fallback, reconnect |
| SSH session to either OS | P1 | Remote application sees the remote PTY and the terminal advertised through SSH | Lossy/delayed output, UTF-8, resize |
| Pipe, CI, `TERM=dumb`, no controlling TTY | P0 | No interactive display assumptions | Predictable refusal or caller-provided noninteractive path |

**Verified platform facts:** SwiftPM supports cross-platform builds and conditional compilation ([Swift package documentation](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode)); the [Swift server build guide](https://www.swift.org/documentation/server/guides/building.html) describes native builds for macOS and Linux. Nothing in the TUI should require AppKit, SwiftUI, Hyprland, Wayland, X11 or a macOS-only framework.

**Design judgment:** Support a *known-modern-terminal baseline* at first rather than integrating a full terminfo database as an upfront dependency. Legacy VT100 compatibility is explicitly out of scope. This is a supported-environment constraint, not a claim that all terminals understand every xterm private mode.

### 3.2 Verified terminal facilities

- [`termios`](https://www.man7.org/linux/man-pages/man3/termios.3.html) provides canonical/noncanonical input and terminal attribute restoration. `cfmakeraw` also disables `ISIG`; Ctrl-C will no longer be generated as a terminal-driver `SIGINT` in that mode.
- [`TIOCGWINSZ`](https://man7.org/linux/man-pages/man2/TIOCGWINSZ.2const.html) obtains terminal dimensions. `SIGWINCH` is the usual notification that dimensions changed; query the actual size rather than assuming a signal conveys it.
- The [xterm control-sequence reference](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) documents alternate screen (`?1049`), cursor visibility, cursor positioning and bracketed paste (`?2004`; `CSI 200~` / `CSI 201~`).
- [`terminfo`](https://man7.org/linux/man-pages/man5/terminfo.5.html) provides structured capabilities including `cup`, `smcup`, `rmcup`, `setaf`, `setab` and `civis` and remains a possible future, narrower compatibility extension.
- The [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) provides opt-in, queryable extended input with a push/pop mode stack. Legacy key encodings are ambiguous, especially for Escape and several Ctrl combinations.
- [Unicode text segmentation UAX #29](https://www.unicode.org/reports/tr29/) describes grapheme boundaries, while [Unicode East Asian Width UAX #11](https://www.unicode.org/reports/tr11/) explicitly warns that East Asian Width alone is **not a complete cell-width algorithm** for modern terminal emulators.
- [tmux's terminal-feature implementation](https://github.com/tmux/tmux/blob/master/tty-features.c) and [FAQ](https://github.com/tmux/tmux/wiki/FAQ) show that terminal features and passthrough are mediated through the multiplexer; do not assume the outer emulator's protocol is directly available inside tmux.
- [`NO_COLOR`](https://no-color.org/) requires suppression of ANSI *colour* if the variable is nonempty; it does not prohibit other useful styling such as bold or underline.

### 3.3 Implementation precedents, not dependencies

- [Ratatui](https://docs.rs/ratatui/latest/ratatui/struct.Terminal.html) separates drawing from the backend and diffs a new frame against the previous one. Borrow the simple buffering idea, not its widget API or Rust abstractions.
- [Bubble Tea](https://github.com/charmbracelet/bubbletea) illustrates explicit state/event/rendering separation. Borrow the discipline, not a command/effect framework that the library has no reason to own.
- Terminal text rendering remains imperfect even among modern emulators. The [Terminal Unicode Core proposal](https://github.com/contour-terminal/terminal-unicode-core) is informative but is not a stable normative specification that eliminates width mismatches.

### 3.4 Local feasibility experiment

A **noninteractive** probe was compiled and run in the research environment using **Swift 6.2.1 on Linux x86-64**. It imported `Glibc` and `Dispatch`, declared native `termios` and `winsize` values, compiled calls to `tcgetattr`, `ioctl(TIOCGWINSZ)`, and created a `DispatchSource.makeReadSource` object. The executed probe correctly reported that the container's stdin was not a TTY. This establishes only API/compiler availability in that environment—not interactive correctness, signal behaviour, macOS compatibility, or Foot support. No app repository was modified.

**Necessary next validation:** compile/run equivalent probes on macOS and perform an actual PTY-backed terminal session with resize and signal injection before freezing the platform layer API.

---

### 3.5 Component toolkit research (added in v2)

The original design cited rendering frameworks but did not extract the key lesson of their **application-facing APIs**. Current Ratatui documents reusable `Block`, `Paragraph`, `List`, `Scrollbar`, `Table` and `Tabs` widgets; its `StatefulWidget` model explicitly separates widget configuration from list-selection/viewport state. [Ratatui widgets](https://docs.rs/ratatui/latest/ratatui/widgets/) and [Ratatui layout](https://www.ratatui.rs/concepts/layout/) inform the small widget/layout vocabulary, without creating a dependency.

[Charm's Bubbles library](https://github.com/charmbracelet/bubbles) provides production-tested distinct single-line input, multiline textarea, list, table and progress components. The lesson is that **text editing and selectable lists are expected built-ins**, not application boilerplate. [Textual's widget guide](https://github.com/Textualize/textual/blob/main/docs/guide/widgets.md) demonstrates focusability and widget-level keyboard handling; adopt that behaviour at a far smaller scale, not the broader runtime.

[Apple's SwiftUI state guidance](https://developer.apple.com/documentation/swiftui/managing-user-interface-state) supports distinguishing domain values from transient view-local state. TerminalUI will not depend on SwiftUI or reproduce its entire observation framework; the comparison is about ownership and identity only.

**Architectural judgment:** implement a single simple value-based `Element` tree with keyed widget-local state, not a framework-specific `View` clone. This remains a **proposal**, to be validated in a compiling Swift package prototype.

## 4. SwiftPM architecture and dependency direction

Use **one public SwiftPM product and module** initially. Internal folders and internal types enforce responsibilities without prematurely shipping multiple packages or publicly exposing low-level dependencies. The widget layer belongs inside this package as a first-class feature.

```text
TerminalUI/
├── Package.swift
├── Sources/
│   ├── TerminalUI/
│   │   ├── Application/              # TerminalHost, TerminalApplication, UIAction
│   │   ├── Elements/                 # Element, ElementID, composition and modifiers
│   │   ├── Layout/                   # measurements, constraints, stack/flex allocation
│   │   ├── Widgets/                  # Text, Paragraph, Panel, List, inputs, Button, Dialog
│   │   ├── Interaction/              # focus, dispatch, WidgetStateStore, shortcuts
│   │   ├── Theme/                    # semantic styles, color policy, key hints
│   │   ├── Geometry/                 # Size, Point, Rect, padding, clipping
│   │   ├── Drawing/                  # Canvas, CellGrid, frame diff, ANSI encoding
│   │   ├── Text/                     # wrapping, width, sanitation, editor algorithms
│   │   └── Internal/                 # native session, byte decoder, scheduler, transport
│   └── CTerminalSupport/            # optional small signals/POSIX shim
├── Tests/
│   ├── TerminalUITests/             # widget, layout, decoder and frame tests
│   └── TerminalUIIntegrationTests/  # PTY, signal and terminal tests
├── Examples/
│   ├── NotesDemo/                   # independent consumer exercising common controls
│   └── WorksheetDemo/               # Parallax-shaped UX with mock data only
└── Documentation/
    ├── QuickStart.md                # examples use widgets, not Canvas
    ├── Components.md                # API, keyboard behaviour and accessibility
    ├── CustomWidgets.md
    ├── SupportedTerminals.md
    └── TerminalProtocols.md
```

Suggested manifest:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TerminalUI",
    platforms: [.macOS(.v13)],
    products: [.library(name: "TerminalUI", targets: ["TerminalUI"])],
    targets: [
        .target(name: "CTerminalSupport", publicHeadersPath: "include"),
        .target(name: "TerminalUI", dependencies: ["CTerminalSupport"]),
        .testTarget(name: "TerminalUITests", dependencies: ["TerminalUI"]),
        .testTarget(name: "TerminalUIIntegrationTests", dependencies: ["TerminalUI"])
    ]
)
```

The C target may be removed if pure Swift interop proves equally safe for signal handling. It is an implementation detail and must not leak through public widgets.

**Dependency rules:**

- `Widgets` can depend on `Layout`, `Text`, `Geometry` and internal paint contexts; they do not call POSIX functions.
- `Interaction` uses widget identity, focusability and event handling. It never invokes application business actions directly.
- `Drawing`, `Text` and `InputDecoder` are independently testable without a real TTY.
- `Application` coordinates the UI actor and bridges the components to transport; app background work remains outside the package.
- **No component requires a full terminal session to be constructed, measured or snapshot-tested.**

The code path for ordinary use is **not** `Canvas` first. `Canvas` is retained for custom widgets, custom borders, diagnostics and package internals.

## 5. Public API: building screens from components

The following Swift declarations specify intended **shape and semantics**, not a claim of compiled implementation. Final names should be adjusted through a small compiler-backed prototype before API freeze. Keep the public surface focused and discoverable.

### 5.1 Application lifecycle and action routing

```swift
@MainActor
public protocol TerminalApplication: AnyObject {
    func view() -> Element
    func handle(_ action: UIAction)
}

@MainActor
public final class TerminalHost {
    public init(configuration: TerminalConfiguration = .init())
    public func run(_ application: any TerminalApplication) async throws
    public func invalidate()
    public func stop()
}

public enum UIAction: Sendable {
    case activated(ElementID)                  // button or list activation
    case textChanged(ElementID, String)        // controlled input value
    case selectionChanged(ElementID, ItemID?)  // controlled list selection
    case dismissRequested(ElementID)           // e.g., Escape in dialog
    case unhandledKey(KeyEvent)                 // optional app shortcut fallback
    case resized(TerminalSize)
}
```

`run` obtains the TTY and emits actions on the main actor after widget handling. The application is responsible for updating its stored state **synchronously within `handle`** (or scheduling its own asynchronous tasks) and for interpreting actions. The host automatically invalidates the frame after an action; externally-driven changes call `invalidate()`. `stop` is idempotent.

Do **not** expose raw key handling as the normal way to use inputs and lists. `unhandledKey` exists for app-level navigation and optional shortcuts; widget-consumed input does not accidentally reach it.

### 5.2 Element identity, composition and dimensions

```swift
public struct ElementID: Hashable, Sendable, ExpressibleByStringLiteral { /* stable ID */ }
public struct ItemID: Hashable, Sendable, ExpressibleByStringLiteral { /* row ID */ }

public enum Dimension: Sendable {
    case fixed(Int)
    case content
    case fill(weight: Int)
}

public indirect enum Element {
    case text(TextElement)
    case paragraph(ParagraphElement)
    case stack(StackElement)
    case panel(PanelElement)
    case scroll(ScrollElement)
    case list(ListElement)
    case input(InputElement)
    case editor(EditorElement)
    case button(ButtonElement)
    case dialog(DialogElement)
    case decoration(DecorationElement)
    case statusBar(StatusBarElement)
    case overlay(OverlayElement)
    case custom(AnyWidget)               // low-level extension escape hatch
}
```

A normal developer uses convenience factories/modifiers, rather than constructing associated-value structs. `statusBar` and `overlay` are ordinary element forms; modifiers such as `.overlay` return a decorated element. Proposed names:

```swift
Element.column(spacing: 1, [/* children */])
Element.row(spacing: 2, [/* children */])
Element.text("Title", role: .heading)
Element.paragraph(longText, wrap: .word)
Element.panel(title: "Details", content: child)
Element.scrollView(id: "details.scroll", content: child)
Element.list(id: "items", rows: rows, selection: selectedID)
Element.textField(id: "search", value: query, placeholder: "Search")
Element.textEditor(id: "question", value: draft, placeholder: "Ask a question")
Element.button("Send", id: "send")
Element.dialog(id: "confirm", title: "Confirm", content: child)
Element.divider()
Element.spacer()

child.width(.fill(weight: 2))
child.height(.fixed(4))
child.padding(.all(1))
child.visible(isVisible)
```

`Element` is a **value description rebuilt when state changes**; no view tree needs to be reconciled for arbitrary property observations. The host traverses it to measure, place, paint and build a focus order. The explicit `ElementID` identifies controls whose caret, selection viewport or focus should survive a rebuild.

The builder uses arrays and ordinary Swift calls. A custom `@resultBuilder`, `@State`-like property wrappers, arbitrary `.onAppear` effects and dynamic environment propagation are **not** part of MVP. Add syntactic sugar only after real screens reveal repetitive code.

### 5.3 Complete high-level consumer example

This example demonstrates the *intended developer experience* and illustrates the desired type signatures; it is not executable until the package is implemented.

```swift
import TerminalUI

@MainActor
final class NotesApp: TerminalApplication {
    private var notes: [Note] = []
    private var selectedNote: ItemID?
    private var draft = ""
    private var showDeleteDialog = false

    func view() -> Element {
        let rows = notes.map { note in
            ListRow(id: note.id, title: note.title)
        }

        return .column(spacing: 1, [
            .text("My Notes", role: .heading),
            .row(spacing: 1, [
                .panel(title: "Notes", content:
                    .list(id: "notes", rows: rows, selection: selectedNote)
                ).width(.fill(weight: 1)),
                .panel(title: "Editor", content:
                    .textEditor(id: "draft", value: draft)
                ).width(.fill(weight: 2))
            ]).height(.fill(weight: 1)),
            .row(spacing: 1, [
                .button("Save", id: "save"),
                .button("Delete", id: "delete")
            ]),
            .statusBar("Tab: focus · Arrows: navigate · Esc: cancel")
        ])
        .overlay(showDeleteDialog ?
            .dialog(id: "delete.dialog", title: "Delete note?", content:
                .row(spacing: 1, [
                    .button("Cancel", id: "delete.cancel"),
                    .button("Delete", id: "delete.confirm")
                ])
            ) : nil)
    }

    func handle(_ action: UIAction) {
        switch action {
        case .textChanged("draft", let text): draft = text
        case .selectionChanged("notes", let id): selectedNote = id
        case .activated("save"): saveDraft()
        case .activated("delete"): showDeleteDialog = true
        case .activated("delete.cancel"), .dismissRequested("delete.dialog"):
            showDeleteDialog = false
        case .activated("delete.confirm"): deleteSelectedNote()
        default: break
        }
    }
}
```

The *intended* result is that normal screen implementation contains no `Rect` calculations, ANSI strings, manual caret drawing, `ScrollState` mutations, keyboard escape parsing or terminal lifetime code.

### 5.4 Built-in widgets and expected behaviour

| Component | Expected responsibility | State ownership | MVP? |
|---|---|---|---|
| `Text` | Single-line label, truncation/alignment, style role | Stateless | Yes |
| `Paragraph` / styled spans | Wrapped, clipped selectable-for-inspection text; no full Markdown parser | Stateless, scroll in wrapper | Yes |
| `Row`, `Column`, `Spacer`, `Divider` | Layout and separation | Stateless | Yes |
| `Panel` | Border, optional title, padding, child clipping | Stateless | Yes |
| `ScrollView` | Viewport, page/arrow scrolling, keep-visible support | UI-local offset | Yes |
| `List` | Selectable rows, keyboard navigation, highlight and ensure-visible | App-selected ID; UI-local viewport | Yes |
| `TextField` | Single-line editing, caret, paste, deletion and horizontal scrolling | App text; UI-local caret | Yes |
| `TextEditor` | Multiline editing, wrapping, selection/caret and paste | App text; UI-local caret/viewport | Yes |
| `Button` | Focusable labelled command; Enter/Space activation | Stateless | Yes |
| `Dialog` | Overlay, focus trap, cancellation request, child controls | UI-local focus; app decides visible | Yes |
| `StatusBar` | Compact status; shortcut hints use secondary `Text` | Stateless | Yes |
| `Table` | Columns, fixed/flex widths, row selection | App selection; UI viewport | Phase 2 if demo requires |
| `Tabs` | Switchable named sections | App selection | Phase 2 |
| Progress/Spinner | Optional passive activity indicator | Provided value / UI clock | Phase 2 |
| Markdown / syntax / diff view | Domain-specific formatting | App/custom widget | Defer |
| Mouse clicks and wheel scrolling | Library-owned hit testing and focus | TerminalUI | Implemented, opt-in; drag-and-drop deferred |

**Feature completeness matters more than component count.** A text editor without reliable paste, cursor restoration, wrapping, selection and resize behaviour does not count as delivered. Similarly, a list must handle focus and scrolling, not just paint item titles.

### 5.5 Focus, keyboard and event precedence

The host assembles a focus chain from visible, enabled, focusable controls in element order. `Tab` and `Shift+Tab` (if supported) change focus; disabled/hidden controls are skipped. A focus ring/highlight is rendered by the library. Focus IDs are stable, not array indices.

Dispatch order:

1. If a dialog is open, **only its subtree** receives interactive input. Underlying controls cannot activate.
2. The focused widget processes normal editing/navigation keys.
3. A declared global shortcut handler, if supplied, receives only unconsumed keys.
4. Other unconsumed keys can become `.unhandledKey` for application navigation.

`TextEditor` interprets Enter as **newline**. It must not silently submit on Enter; a separate focused `Button` or a deliberately configured, terminal-reliable shortcut triggers submission. Do not depend on Shift+Enter/Ctrl+Enter being distinguishable on legacy terminals. Escape in a dialog emits `.dismissRequested`, **not** an implicit approval or deletion. `Button` activation emits an ID only; business semantics stay in application code.

### 5.6 State ownership: controlled values, persistent local mechanics

A redraw rebuilds the element tree. Inputs receive their **current text values** from app state and send `.textChanged` after editing. Lists receive selected `ItemID` and send `.selectionChanged`. The package retains only mechanical UI state in a `WidgetStateStore` keyed by `(ElementID, widget kind)`:

- focused ID, editor caret/selection and editor viewport;
- list visible-row range, scroll offsets and local hover/highlight where applicable;
- dialog return-focus target and optional layout cache.

A control removed from the tree has no active focus and its unused state is eligible for bounded eviction. Reusing the same ID for a different semantic document can accidentally preserve the wrong caret/scroll; consumers must use **stable semantic IDs** and explicitly reset when a document or worksheet revision changes. The API must provide `resetState(for:)` or a comparable scoped identity mechanism. On text replacement, clamp/correct the caret to the new value.

No application data, agent information or repository content is stored in `WidgetStateStore`. Text values are always authoritative from the consumer, preventing the visual editor and app model from diverging.

### 5.7 Custom controls without forking the package

A public `CustomWidget` protocol should allow drawing inside assigned bounds and handling input, using the same focus, theme and semantic-action rules as built-ins. A consumer can introduce a code diff, graph or specialised evidence widget without touching terminal bytes.

```swift
@MainActor
public protocol CustomWidget {
    var id: ElementID? { get }
    var isFocusable: Bool { get }
    func measure(_ proposal: SizeProposal, context: MeasureContext) -> Size
    func draw(in canvas: inout Canvas, bounds: Rect, context: DrawContext)
    func handle(_ key: KeyEvent, context: WidgetEventContext) -> WidgetResponse
}
```

The host wraps a conforming widget as `Element.custom(...)` with type erasure internal to the package. Keep this protocol narrow and actor-isolated; do **not** expose raw terminal transport, a second rendering pipeline, or asynchronous work inside `draw`. Default no-op event handling supports noninteractive custom widgets. The exact protocol should be stabilised *after* built-ins prove the necessary capabilities.

### 5.8 Lower-level developer API

Retain `Canvas`, `Rect`, `TextStyle`, `TerminalEvent`, `KeyEvent`, `TextEditorState` and text-width utilities where valuable for custom widgets and tests. Keep terminal byte parsers and native session types internal. Some low-level internals may be `package` visibility rather than `public` if the consumer has no reason to use them.

### 5.9 What not to build

No universal view hierarchy, `@State` clone, animation engine, constraint solver, layout scripting language, reactive subscription graph, full CSS, terminal image protocol, plugin registry, data source ORM or application router. This is a **real component toolkit**, not an unrestricted UI framework.

## 6. Terminal session and process lifecycle

This is a correctness-critical subsystem. The operating system terminal and process signal environment are external shared resources, not arbitrary `Sendable` values.

### 6.1 Acquire a terminal explicitly

1. Try opening `/dev/tty` for reading/writing to locate the process's controlling terminal, even if stdin/stdout are redirected. If unavailable, fail with `TerminalError.noInteractiveTTY`; do **not** print control sequences into a pipeline.
2. Verify `isatty`, collect original `termios`, record dimensions with `TIOCGWINSZ` and inspect `TERM`/locale hints.
3. Refuse `TERM=dumb` and unusable dimensions in interactive mode, with a clear error. An app may offer a separate line-mode CLI, but that is outside this library.
4. Set noncanonical mode, disable echo, byte-processed input and XON/XOFF; record every state change for reversal. Choose `VMIN`/`VTIME` consistently with nonblocking reads.
5. Enter alternate screen, enable bracketed paste and hide cursor (where supported). Do not enable mouse/focus/Kitty modes unless the corresponding decoder is ready to consume them.
6. Start the input and signal sources, schedule an initial full render.

`cfmakeraw` is a convenient reference but is not enough for lifecycle policy: it disables `ISIG`, so Ctrl-C becomes an input byte to interpret, not a terminal-driver signal. The MVP should map Ctrl-C to an application cancellation/quit intent; the *application* decides whether this means cancelling the editor, cancelling an operation or quitting.

### 6.2 Ownership and teardown

Use one `TerminalSession` per process, guarded by an explicit state machine:

```text
idle → acquiring → active → restoring → closed
               ↘ failed ───────→ closed
```

There must be a single finalisation path, shared by explicit stop, thrown errors, `SIGTERM`, `SIGHUP`, terminal hangup and ordinary process exit. Teardown should be idempotent and should attempt all necessary reversals even if one step fails:

1. Stop accepting terminal events and cancel pending input/output sources.
2. Drain or abort buffered display bytes according to a bounded shutdown policy; ensure reset bytes have the best possible delivery opportunity.
3. Reset any opt-in keyboard protocol state.
4. Disable bracketed paste, restore cursor visibility and style, exit alternate screen.
5. Restore the **saved original** `termios`, rather than assuming `stty sane` describes the user's prior configuration.
6. Restore signal dispositions and close owned file descriptors.

The ordering of terminal escape cleanup versus `termios` restoration must be proved on both OSes with real terminals and failed-write tests. Do not state that a `defer` alone guarantees restoration: `SIGKILL`, hard process crashes and PTY loss cannot be reliably handled inside Swift. Document shell recovery commands (`stty sane`, `reset`) for unavoidable cases.

### 6.3 Signals: do not execute Swift app logic in a signal handler

A minimal POSIX C shim is recommended for installing signal handlers and waking the event loop through a nonblocking self-pipe. The handler performs only async-signal-safe operations such as writing a byte to a pre-established FD. All interpretation, redraw, teardown and errors occur in ordinary Swift execution. This follows [POSIX async-signal-safety guidance](https://man7.org/linux/man-pages/man7/signal-safety.7.html).

- `SIGWINCH`: wake, requery dimensions, invalidate and redraw fully.
- `SIGTERM`, `SIGHUP`: request an orderly stop/restore.
- `SIGINT`: because the terminal is in raw-like mode, typed Ctrl-C usually arrives as input; still handle an externally delivered SIGINT as a shutdown request.
- `SIGPIPE`: ensure a closed terminal/output produces an error rather than unexpectedly terminating without cleanup; preserve prior disposition on exit.
- `SIGTSTP`/`SIGCONT`: **explicitly defer interactive job-control suspension** unless implement/verify a full restore-before-stop, reacquire-after-continue flow. In the first milestone Ctrl-Z is not advertised as supported. An externally delivered forced stop remains an unavoidable limitation.

Use a conservative **single-active-session** contract because terminal attributes and process signal dispositions cannot safely be managed as independent per-widget instances. Do not mask signals or hijack existing handlers without documenting the process-level effect. A purely Swift implementation is acceptable only if it offers the same async-signal-safe guarantees.

### 6.4 PTY details

Treat a PTY-backed interactive session as the normal environment. On macOS/Linux the TUI sees character-cell dimensions and byte streams; it does not know about the window manager. No code path should query Hyprland, a Mac display, or GPU properties. With tmux, `TERM` refers to tmux's terminal model and its advertised capabilities, not necessarily Foot/Kitty outside the multiplexer.

---

## 7. Terminal capabilities and protocol policy

### 7.1 MVP baseline

Use a limited xterm-compatible subset:

| Feature | Mechanism | Policy |
|---|---|---|
| Address cursor | `CSI row;column H` | Required |
| Clear screen/line | CSI erase commands | Required |
| Style | SGR | Mono + 16 colours baseline |
| Alternate screen | DEC private `?1049h` / `?1049l` | Default for full-screen host |
| Cursor visibility | `?25l` / `?25h` | Explicitly tracked |
| Bracketed paste | `?2004h` / `?2004l` | Default when available |
| Navigation keys | Legacy CSI/SS3 forms | Required |
| Mouse | Normal tracking `?1000` with SGR `?1006` | Implemented, opt-in; see [current behavior](../../../README.md) |
| Kitty keyboard | `CSI ? u` query, push/pop flags | Optional enhancement after fallback tests |
| Focus reporting | `?1004` | Deferred |
| Synchronized updates | `?2026` | Deferred optimization |
| OSC 52 clipboard | Terminal-dependent | Not sent in MVP |
| OSC 8 hyperlinks | Terminal-dependent | Deferred |

**Do not assume a capability based solely on a terminal name string.** Derive a conservative baseline from the supported profile and environment. Optional features should be negotiated or explicitly overridden, and should time out safely when the terminal does not respond. The parser must distinguish replies to app-initiated terminal queries from user keyboard events.

### 7.2 Why not terminfo from day one?

There are three plausible choices:

| Approach | Benefits | Cost/risks | Decision |
|---|---|---|---|
| Hard-coded, carefully bounded VT/xterm sequences | Minimal, easy to test, no linking concerns | Not universal; responsibility for supported-emulator matrix | **MVP** |
| Low-level terminfo (`setupterm`, `tigetstr`, `tparm`) | Capability lookup and portable terminal sequences | C ABI/linking, runtime databases, platform differences and terminfo complexity | Add if real tests reveal incompatibility |
| ncurses or other whole TUI toolkit | Mature capability support and widgets | Runtime dependency and own drawing/layout model | Reject for this project |

**Reconsideration trigger:** repeated incompatibilities between Foot, macOS Terminal, tmux and supported profiles that would otherwise require accumulating many hard-coded terminal-specific exceptions. If reached, add a *capability adapter*, not a replacement UI framework.

### 7.3 Keyboard enhancement

Legacy input supports a useful MVP but is fundamentally ambiguous: Esc vs an escape-sequence prefix, Shift+Enter in some terminals, and certain Ctrl-key combinations. Start with terminal-independent controls: arrows, Enter, Escape, Tab, Ctrl-C, Ctrl-D, printable text and explicit on-screen shortcuts. Never require a chord that legacy terminals may collapse into another key.

Kitty support, when enabled, should:

1. Query support with a bounded response window.
2. If supported, push only the flags required (initially disambiguation, not every key release/repeat event).
3. Decode `CSI u` into normalised `KeyEvent` values.
4. Pop the exact mode stack level during teardown.
5. Fall back to legacy without impacting the app if unsupported, timed out or intercepted by tmux.

Do not send Kitty push sequences speculatively to every supported terminal. Refer to the [Kitty protocol's negotiation and stack semantics](https://sw.kovidgoyal.net/kitty/keyboard-protocol/).

---

## 8. Input decoder

### 8.1 Model

The reader obtains arbitrary byte chunks from the TTY. An `InputDecoder` consumes bytes incrementally and emits **complete semantic events**. It must never assume one `read` corresponds to one key, UTF-8 scalar or escape sequence.

```text
TTY bytes
  ↓
nonblocking read
  ↓
InputDecoder
  ├─ UTF-8 text → .key(.character(...))
  ├─ C0/key codes → .key(...)
  ├─ CSI / SS3 → navigation or future extended key
  ├─ CSI 200~ ... CSI 201~ → .paste(text)
  ├─ known terminal response → private capability handler
  └─ malformed / unsupported → bounded discard, diagnostic counter
```

Suggested states: `normal`, `pendingEscape`, `csi`, `ss3`, `utf8`, `paste`, and `terminalReply`. Keep parser state size bounded. Use explicit maximum escape-sequence length, maximum numeric parameters and strict digit parsing to avoid overflow or unbounded memory growth.

### 8.2 Escape ambiguity

When a standalone `0x1b` is read, the decoder cannot immediately know whether it means Escape or the start of CSI/Alt. Start a configurable short deadline (proposed 30 ms; actual value to validate) and emit Escape if no valid continuation arrives. This is a legacy protocol limitation, **not** evidence of a particular framework bug. In remote high-latency SSH sessions, a short deadline could misdecode; expose a tuning option and prefer negotiated disambiguation where supported. Include a fake clock in unit tests; do not use wall-clock sleeps.

### 8.3 Paste is text, never commands

With bracketed paste enabled, text between `CSI 200~` and `CSI 201~` becomes **one `.paste` event**. The paste body must not run normal shortcut decoding. Use a bounded buffer (proposal: 1 MiB by default, configurable) and emit an explicit truncation/rejection outcome when exceeded; do not silently accept incomplete data. Filter or display control characters safely before any inserted text is rendered.

There is no cryptographic authentication of bracketed-paste delimiters. A malicious pasted byte stream containing the end delimiter can terminate the paste early; therefore critical application actions must not be executable merely by untrusted pasted or decoded terminal text. This is especially important for Parallax approvals, but **the approval rule is owned by the app**.

### 8.4 Robustness requirements

- UTF-8 split between reads, invalid byte sequences, NULs, carriage returns and backspaces.
- Arrow and navigation sequences in both common CSI/SS3 forms.
- Unrecognised CSI/OSC/DCS sequences safely discarded or routed to an explicit diagnostic, never emitted as keystrokes piecemeal.
- Bracketed-paste delimiter split at every possible byte boundary.
- A terminal response arriving while the user types.
- Multiple complete events in one read.
- EOF/hangup and interrupted reads without busy loops.
- No unbounded queue when application code is slow.

---

## 9. Text, Unicode and layout

**This is likely to be the most challenging rendering subsystem after terminal lifecycle.** Swift's `Character` addresses segmentation of user-perceived characters but does not determine the number of *terminal cells* a glyph occupies. A composed emoji may contain several scalars yet occupy two columns; a combining sequence should not be painted as separate cells.

### 9.1 Recommended text pipeline

```text
String
  → sanitise unsafe controls
  → segment into Swift Characters / extended grapheme clusters
  → determine display width of each cluster (0, 1 or 2)
  → wrap and clip to cell columns
  → write cells, including a continuation marker for width-2 clusters
```

Represent each visible glyph as a grapheme string attached to the **leading** cell; the following cell for width-2 clusters is a continuation cell. Never allow a write to begin inside the continuation cell of an existing wide glyph. On overwrite, erase the whole prior grapheme footprint before installing new cells. All layout and scrolling use **display columns and rendered rows**, not Swift string indices or UTF-8 byte counts.

### 9.2 Width algorithm

Expose one internal `CellWidth` service. Do not scatter `unicodeScalars.count`, `.count` or POSIX `wcwidth` calls throughout the renderer. Candidate initial strategy:

1. Use Swift `Character` segmentation, preserving complete grapheme clusters.
2. Apply a versioned width policy informed by Unicode properties, common fullwidth/wide ranges, combining sequences and emoji presentation; verify against actual emulators.
3. Treat ambiguous-width characters as single-column by default in the supported English-oriented terminals, with a future override only if there is demonstrated need.
4. For unknown or unsupported clusters where width cannot be safely predicted, substitute a visible replacement glyph during rendering rather than corrupting the terminal grid. Preserve original source text in application state.
5. Include a manual terminal probe screen to compare expected versus actual widths, particularly for emoji ZWJ sequences, flag emoji and variation selectors.

`wcwidth` is an available input to evaluation, but it operates on individual wide characters and depends on locale and platform implementation. Neither it nor East Asian Width directly solves multi-scalar grapheme width. **Do not globally mutate the process locale on every render**; establish and document UTF-8 assumptions once on startup, and be conservative where the host and terminal disagree.

### 9.3 Wrapping and scrolling

Implement predictable hard/soft wrap for plain text:

- Respect explicit newlines; normalise CRLF for editor content.
- Prefer whitespace boundaries where feasible; hard-break overlong words and paths.
- Recompute editor visual rows on width changes and text edits; preserve logical caret position.
- Provide clipping, vertical scroll and an `ensureVisible` operation for the caret or selected item.
- Avoid tab ambiguity by expanding tabs at controlled tab stops (default 4) while rendering.
- Do not attempt full Unicode bidirectional layout in v1; document reduced fidelity for complex RTL and mixed-direction content.

### 9.4 User-visible safety

Never put arbitrary file names, compiler output, model responses or pasted text directly into a terminal output byte stream. Strip or visibly replace C0/C1 controls, ESC, OSC/DCS introducers and unexpected terminal control sequences. Preserve newline/tab only when rendering through the structured text path. Escape ANSI-bearing content **even if** it looks like harmless coloured logs. ANSI emitted by the package is generated by trusted encoder functions only.

---

## 10. Rendering pipeline and output correctness

### 10.1 From app state to terminal cells

The rendering pipeline gains **two pure high-level stages**, then retains the original reliable cell renderer:

```text
Application state
   │  view()
   ▼
Value-based Element tree (small and disposable)
   │  discover IDs, focusability and widget kinds
   ▼
MEASURE  — intrinsic sizes, fixed sizes, flex weights, min/max bounds
   │
   ▼
LAYOUT   — assign integer Rects, clip and generate focus order
   │
   ▼
PAINT    — built-in widgets/custom widgets draw into Canvas
   │
   ▼
CellGrid — complete desired screen
   │
   ▼
Diff against last successfully committed screen
   │
   ▼
Single-owner ANSI encoder + bounded terminal write queue
```

**No general-purpose view diffing is needed.** Rebuild and lay out a small tree on redraw; terminal-cell diffing limits output bytes. Persistent state belongs only to explicitly identified interactive widgets.

### 10.2 Layout algorithm

Implement deterministic layout in two simple passes:

1. **Measure:** ask elements for preferred/available size under the parent proposal. A `Text` reports cell width; a wrapped `Paragraph` calculates height for offered width; a `Panel` adds border/padding. Fixed dimensions are respected within bounds. A fill dimension takes available space and its integer weight among siblings.
2. **Place:** each `Row`/`Column` allocates fixed/content requirements, spacing and residual fill. Clip to parent bounds and saturate at zero. A `Panel` lays out its content in its inset rectangle. Overlay/Dialog is measured against the terminal viewport, then placed last.

Keep integer cell geometry, not percentage floats or arbitrary layout constraints. Report diagnostic counters on impossible constraints; do not trap on a 20-column terminal. A `Row` may overflow and clip; **responsive substitution is owned by the app** (e.g. choose a column in narrow width). The library should expose available size or a small `Adaptive` element with explicit breakpoint conditions if the demos need it. Do not insert hidden app-specific breakpoints into the layout engine.

### 10.3 Cell representation

An internal grid cell can be described as:

```swift
struct Cell: Equatable {
    var grapheme: String
    var width: UInt8        // 0: continuation, 1: normal, 2: wide leading
    var style: TextStyle
}
```

Every element paints through a clipped canvas; no raw ANSI is emitted by widgets. Opaque and overlaid regions have a defined clear/fill policy to avoid stale screen content when a dialog closes. Wide glyphs clipped at cell boundaries use a documented fallback rather than writing half a grapheme.

### 10.4 Diff and transaction contract

1. Create the complete new grid; on resize/first frame consider the whole screen dirty.
2. Compare cells against the **last fully committed** frame, coalescing changed runs and respecting wide-glyph boundaries.
3. Emit cursor moves, SGR and UTF-8 via a single trusted encoder.
4. Queue writes with bounded backpressure, handle partial writes/EINTR/EAGAIN and terminal disconnects.
5. **Commit the frame only after all its output bytes are written successfully.** If a partial frame is discarded or fails, mark the screen unknown and perform a full redraw when possible.
6. Cursor show/hide and placement are resolved after widget drawing; an active editor's caret takes precedence. Avoid accidental bottom-right autowrap effects.

Do not draw an old modal frame over new app state or interleave frame writes. Do not run a continuous 60 FPS repaint loop. Coalesce invalidations; a proposed 30 FPS ceiling for bursty activity is sufficient until measured otherwise. Optional synchronized terminal updates (`DEC ?2026`) may be added after core correctness, never as a prerequisite.

### 10.5 Performance expectations

A ~120×40 screen is small: whole-tree measurement and grid rendering should be straightforward. Benchmark with: 100 text elements, 200 list entries, 10,000 evidence records backed by a lazy source, a long Unicode paragraph and rapid async status updates. If producing thousands of off-screen list rows is expensive, add list virtualization at the data-source boundary; do not introduce a full retained view reconciler prematurely. Cache text measurement only when profiling justifies it, keyed by content and available width.

## 11. Runtime, concurrency and updates

The host and widget/event tree are isolated to `@MainActor`. Native transport performs nonblocking I/O without blocking the UI actor. User actions reach application state in sequence; background tasks update their own state and invalidate the view through a main-actor handoff.

```text
Background work (application-owned Swift tasks/actors)
           │ snapshot / state change
           ▼
Application object (@MainActor)
           │ view()                ▲ handle(UIAction)
           ▼                       │
TerminalHost (@MainActor): input → focus dispatch → widgets
           │ element/layout/paint
           ▼
Cell buffer + output transport
           ▲
Input decoder ← nonblocking TTY reader
```

### 11.1 State and update contracts

- `view()` is synchronous; it must not `await`, run tools or access a mutable cross-actor model unsafely. It returns a new value tree for the current snapshot.
- `handle(_:)` is synchronous. A text-change action **must update the corresponding controlled value immediately** so the next view remains consistent; any expensive side effect is kicked off in an application-owned task.
- Widget-local state has one UI-actor owner and stable-ID reconciliation; no widget performs its own unstructured background work.
- External updates call `host.invalidate()` (or an actor-safe equivalent) to coalesce rendering.
- A busy execution agent must never block editing or focus traversal. Package-level cancellation only stops terminal hosting, not application tasks.
- Redraws are non-reentrant. If state invalidates during drawing, schedule a following frame, not a nested render.
- Interaction ordering is deterministic: decoded input → widget state change → `UIAction` → app state change → tree rebuild → layout → paint.

### 11.2 Resizing and disappearance

Resize remeasures/reflows the entire element tree, clamps viewports and keeps the focused caret or selected list row visible when possible. If a focused element disappears, choose the nearest remaining focusable successor (or clear focus). An overlay replaces the active focus scope; closing it should attempt to restore previous focus. Document exact focus fallback so apps can rely on it.

### 11.3 Parallax integration example (design seam only)

A Parallax screen could store `worksheetText`, `evidenceRows`, `selectedEvidenceID`, `questionDraft`, `activeScreen`, and `showApprovalDialog`. Its `view()` composes `Panel`, `Paragraph`, `ScrollView`, `TextEditor` and `Dialog`. Its `handle(_:)` interprets `.activated("approve")` as *request to begin an application-level approval workflow*, **not** an approval executed by the TUI. A separate Parallax service enforces worksheet-revision validity and explicit human consent.

The TUI never receives credentials, tool executors, worksheet revisions or model client handles. It receives content and reports human interaction IDs/text changes only.

## 12. Day-to-day composition, layout and interaction guidelines

### 12.1 Application authors should compose, not paint

**Normal experience:**

```swift
let content: Element = .column(spacing: 1, [
    .text("Task summary", role: .heading),
    .panel(title: "Worksheet", content:
        .scrollView(id: "worksheet", content:
            .paragraph(worksheetText)
        )
    ).height(.fill(weight: 1)),
    .textEditor(id: "question", value: questionDraft)
        .height(.fixed(4)),
    .row(spacing: 1, [
        .button("Ask", id: "ask"),
        .button("Evidence", id: "evidence")
    ]),
    .statusBar("Tab: focus  ·  Enter: activate")
])
```

No `canvas.drawBorder`, `Rect.splitHorizontal`, `editor.handle(event)` or manual focus index is required here. The application supplies data and maps emitted action IDs to its own functions.

### 12.2 Layout and containers

- `Column` and `Row`: arrange children with cell-based spacing, optional alignment, fixed/content/fill dimensions and clipping.
- `Panel`: borders, titles and padding as one reusable element; child draws inside content bounds.
- `ScrollView`: manages viewport position independently from child content and current terminal height.
- `Overlay` / `Dialog`: draws after the normal tree and disables focus below its active scope.
- `Spacer`, `Divider`, `Padding`: routine composition affordances, not custom screen code.
- `Adaptive` (conditional MVP): explicit switch between row and column based on size if Parallax-shaped demo needs it; can initially be done by application checking the reported size.

Avoid broad constraint solvers. The intended 80/20 abstraction is **content / fixed / weighted fill** for width and height.

### 12.3 Focus and keyboard usage

A default focus manager automatically handles Tab/Shift+Tab, Enter/Space on buttons, cursor movement within inputs and arrows/PageUp/PageDown in scrollables. Visual focus is differentiated from row selection: a list may have a selected item while a text editor has focus. Escape dismisses the top dialog via a request event, otherwise may be delivered to the app. Applications can declare explicit shortcut bindings, but package rules prevent bypassing active text editing or modal focus.

The key legend/status component can render the actual shortcuts supported by the active terminal mode. Do not advertise ambiguous combinations such as Ctrl+Enter when legacy decoders cannot report them separately.

### 12.4 Responsive Parallax-shaped screen

At 100–120 columns, a worksheet beside evidence can be useful; at 60–80 columns a single main panel with a toggleable inspector is clearer. **Parallax chooses when to display the inspector;** the TUI measures and places whatever subtree is returned.

```text
┌─ WORKSHEET r7 ───────────────────────────────────────────────┐
│  Current understanding ...                                  │
│  • Constraint / observation / concern                       │
│  (scrolls; underlying activity not automatically streamed)  │
├─ Ask about worksheet ───────────────────────────────────────┤
│  Why was the cache invalidation approach chosen?            │
│  ▌                                                          │
├─────────────────────────────────────────────────────────────┤
│ [Ask] [Evidence] [Revision] [Direction]   Agent: running     │
└─────────────────────────────────────────────────────────────┘
```

A question produces app-owned interrogation history, not library-owned persistent state. A proposed revision may use a composition of two panels and styled paragraphs initially; a specialised diff widget can follow if it materially improves usability.

### 12.5 Dialog interaction and approval safeguards

A dialog traps focus and presents explicit buttons. It may style a destructive choice differently but **must never imply that the underlying action has happened**. Application code must independently validate that an approval remains relevant and permitted after the event. The TUI must not execute domain commands or run subprocesses from a button's internal event handler.

### 12.6 Theme and style semantics

Expose a compact `Theme` palette (`normal`, `muted`, `heading`, `accent`, `selection`, `focused`, `warning`, `error`, `border`) with default light/dark-neutral compatible terminal colours, 16-colour or monochrome fallbacks and `NO_COLOR` support. Widgets use semantic styles rather than inventing numeric ANSI sequences. A consumer can override roles; a full CSS/cascade engine is not required.

### 12.7 Building a new widget

For a component not covered by the baseline, implement `CustomWidget` (or a protocol with equivalent capabilities) with explicit measurement, painting and input logic. Package layout and focus still apply. Promote a custom widget into the standard library **only after it has general value across more than one screen or sample**.

## 13. Security, reliability and accessibility

### 13.1 Untrusted text boundary

App data can contain model output, terminal logs, Git diff content and repository files. Rendering that data through trusted `Canvas` text operations must never execute embedded escape sequences. Required tests include OSC 52 attempts, `ESC[2J` clear-screen, cursor movement, changes to terminal title, bidi controls and literal tabs/newlines. Bidi formatting controls may need a visible notation in security-relevant evidence rather than silent removal; design that as a selectable *text display policy* without changing stored source content.

Also bound text-render input length to prevent an accidentally enormous model response from freezing the UI. Virtualise long text views or calculate only the visible portion once profiling proves necessary; do not begin with a generalized virtual-list framework.

### 13.2 No accidental approvals through transport

The TUI provides raw semantic events; it must never synthesize affirmative UI actions from paste contents, terminal responses or unknown CSI sequences. An app must require intentional user direction and separately confirm consequential actions. This property should be demonstrated by a sample app test where pasted strings or malicious output cannot trigger a confirmation handler.

### 13.3 Failure modes

| Failure | Expected behaviour |
|---|---|
| No TTY / `TERM=dumb` | Typed error, no ANSI output |
| `tcsetattr` fails | Abort acquisition, restore anything already changed |
| Resize to tiny/zero dimensions | Clamp, show minimal status or wait; no allocation crash |
| Terminal read returns EOF | Exit session and attempt restore |
| Short write / `EAGAIN` | Resume output asynchronously; no interleaved frames |
| Output permanently fails | Mark display state unknown, tear down and return error |
| SIGTERM / SIGHUP | Request orderly restore through normal event loop |
| Process SIGKILL | Cannot guarantee restoration; documented limitation |
| Very large paste | Reject/truncate explicitly with user-visible outcome |
| Unsupported key sequence | Ignore safely and optionally record bounded diagnostics |
| Unicode width mismatch | Use tested fallback and a diagnostics/probe mode |

### 13.4 Accessibility

Provide a high-contrast/monochrome mode, a predictable keyboard-first focus order (owned by app), textual status indicators that do not rely solely on colour, alternative ASCII borders, configurable ESC timeout, and no reliance on mouse input or animation. A TUI cannot claim comprehensive screen-reader compatibility across all terminal configurations; test assistive use on supported environments, and document the limitations honestly.

---

## 14. Validation and regression strategy

### 14.1 Pure widget and layout tests (every OS)

- Snapshot test every built-in component at normal, tiny, zero-width/height and oversized bounds.
- Verify fixed/content/fill distribution, integer rounding, padding, clipping, borders and dialog positioning.
- Test `Row` and `Column` against nested content, wrapped paragraphs and difficult Unicode.
- Verify modal overlay completely clears/repaints on opening/closing, without stale characters.
- Assert stable IDs preserve editor caret and list viewport across value-tree rebuilds, but a new identity resets them.
- Assert a list selection is keyed by item **ID** rather than shifting unexpectedly when rows reorder.
- Assert a removed, disabled or hidden control is not focusable; Tab traverses only visible enabled elements.
- Verify keyboard consumption precedence: editor eats typing, list eats arrow keys, dialog traps focus, only unconsumed keys reach app shortcuts.
- Test paste into an editor as data, including embedded newlines and control sequences: no button activation and no raw escape output.
- Test editor wrapping, selection, logical cursor versus visual rows and scroll-to-caret on resize.
- Test `UIAction` ordering: changing text updates app model before the following `view()` is drawn.
- Test the custom-widget protocol with a minimal third-party element that can measure, paint and receive focus.

Use a fake clock and fake terminal transport for deterministic event and lifecycle tests. Prefer semantic assertions (which widget is focused, emitted action, visible viewport) alongside full-frame snapshots.

### 14.2 Input, text and render tests

- Every split point of UTF-8, CSI/SS3 and bracketed paste delimiters; escape timeout with a fake clock.
- Corrupt or unsupported escape sequences, malformed Unicode, exceptionally long paste and missing terminators.
- CJK, combining marks, emoji modifiers, flags and ZWJ graphemes; width mismatches against real supported terminals.
- Wide glyph partially clipped at viewport edge; wrap and scrolling continuity.
- Cell diff invariants, bottom/right edges, full redraw on resize, partial output writes, dropped uncommitted frames.
- Untrusted repository/agent output cannot emit raw terminal control sequences.

### 14.3 PTY and OS tests

Run terminal session lifecycle, resize, signal cleanup, TTY absence, tmux behaviour, Ctrl-C, EOF and paste exercises on **macOS Terminal.app** and **Omarchy Foot** first; add macOS Ghostty, Alacritty, Kitty and SSH according to availability. The Linux compile-only probe recorded in section 3 does **not** prove interactive correctness. Restore saved `termios` on all recoverable normal exits and errors; document unavoidable `SIGKILL`/process-crash limitations.

### 14.4 Two required user-facing demos

**NotesDemo:** note list, multi-line editor, save/delete buttons, confirmation dialog, status bar, resize, scrolling and focus. Building this must require no direct `Canvas` calls.

**WorksheetDemo:** stable worksheet, independent evidence inspector, question editor, revision preview and direction-confirmation view using mock data. It may build application-specific compositions but must not add Parallax imports to the library.

### 14.5 Meaningful success criteria

1. A consumer writes a working CRUD-style keyboard interface primarily by composing built-in elements.
2. Both demos run on macOS and Omarchy, including 80×24, 120×40 and a cramped 60×18 viewport (with graceful clipping/reflow chosen by the app).
3. Routine widget behaviour (focus, scroll, editing, selection, dialog) is implemented once in the package rather than duplicated per screen.
4. UI remains responsive during simulated background model/tool activity.
5. No raw terminal bytes escape through untrusted text; terminal modes restore on normal/error termination.
6. Snapshot tests and action traces remain deterministic across redraws.
7. Public library code contains no Parallax-specific concepts or agent integration.

## 15. Incremental implementation plan — components are a core milestone

Avoid postponing common widgets until after application integration. The previous plan deferred abstractions too aggressively; the new plan implements a **usable high-level vertical slice early** while validating the terminal engine underneath.

| Milestone | Working deliverable | Acceptance gate |
|---|---|---|
| **0. Terminal proof** | Probe TTY acquisition, raw mode, signal handling, resize and UTF-8 on macOS and Foot | Restores shell, supports real PTY, no platform-only assumptions |
| **1. Renderable element spine** | SwiftPM target, terminal lifecycle/input, `Element.text`, `Column`, `Panel`, `CellGrid` and diff renderer | A full-screen labelled panel renders through elements, not manual Canvas in app |
| **2. Layout and focus** | `Row`, fixed/content/fill, padding, focus manager, `Button`, semantic `UIAction` | Small interactive navigation demo; Tab and Enter work out of the box |
| **3. Scroll and list** | `Paragraph`, `ScrollView`, `List`, selection IDs and viewport persistence | Notes list navigates/scrolls/resizes without app key-routing boilerplate |
| **4. Editors and dialogs** | `TextField`, multi-line `TextEditor`, bracketed paste, `Dialog`, focus trap | NotesDemo works end to end with no application Canvas calls |
| **5. Parallax-shaped validation** | Independent worksheet/evidence/interrogation/review/confirmation demo | All required Parallax interactions expressible through library components |
| **6. Reliability + extensibility** | PTY tests, Unicode corpus, terminal restore, backpressure, custom widget escape hatch | Linux/macOS test matrix and user-facing interaction traces pass |
| **7. API review and first release** | Docs, sample apps, semantic theme and concurrency review | Independent consumer can build a practical terminal application from docs |

### What is intentionally deferred

SwiftUI-style result builders/property wrappers, arbitrary reactive bindings, complex layout constraints, virtual DOM optimisations, rich Markdown, full code-diff widget, generalized tables, charting, terminal graphics, theme CSS, mouse dragging and continuous hover effects, clipboard writes, complex animation and full bidi layout. Add only when demos or measured usage create a clear requirement.

**Milestone review principle:** low-level correctness and high-level usability must advance together. A stable `Canvas` with no usable components is **not** a successful foundation for Parallax.

## 16. Technical risks and decisions to validate

| Risk | Consequence | Mitigation / decision gate |
|---|---|---|
| **UI API too low level** | Every app repeats layout, focus, scrolling and editing | Require NotesDemo with component-only composition; review API ergonomics |
| **UI API too broad** | Framework maintenance overwhelms Parallax work | Fixed component vocabulary, simple stack layout, no general reactive runtime |
| Widget identity errors | Lost caret/focus or wrongly reused state | Semantic `ElementID`, controlled values, explicit scoped reset, identity tests |
| Layout complexity | Unpredictable behaviour in narrow terminals | Integer fixed/content/fill model, clipping, app-chosen responsive mode |
| Focus/event collisions | Text typing triggers shortcuts or hidden buttons | Single focus dispatcher and modal isolation, interaction trace tests |
| Controlled-input synchronisation | Editor diverges from app's text | Synchronous `.textChanged` handling and authoritative app value on redraw |
| Large collections | Build and layout stalls on thousands of rows | Visible-range rendering / lazy row provider if benchmark demands it |
| Terminal restore failure | Corrupted shell after exit | Single terminal session, signal-safe wakeups, PTY tests on both OSes |
| Unicode display-width mismatch | Broken layout or overwritten cells | Central width algorithm, fallback glyphs, tested corpus |
| Input ambiguity | Broken keybindings over SSH/tmux | Conservative legacy shortcuts; optional negotiated keyboard protocol |
| Slow output / partial writes | Inconsistent physical screen | Commit only after successful complete write; bounded queue |
| Portable Swift ABI assumptions | macOS/Omarchy compilation failures | Early native builds and tiny conditional POSIX/C shim |
| Business-policy leakage | Button implicitly changes agent instructions | UI reports semantic action IDs only; domain approval remains outside package |

### Open decisions and research spikes

1. **API shape:** implement the simple `Element` enum/factory interface in a single demo and compare it with a small struct-based `Widget` approach. Choose based on source readability, compiler feedback and custom-widget viability—not aesthetic allegiance to declarative frameworks.
2. **WidgetStateStore lifecycle:** define what happens on hide, conditional removal, document change and ID reuse. Test all transitions before API freeze.
3. **Input delivery:** Dispatch read/write sources versus a dedicated poll worker; verify on both supported OSes.
4. **Signal shim:** native Swift or minimal C for async-signal-safe self-pipe and lifecycle integration.
5. **Unicode width:** select a versioned display-width policy from real terminal tests; `wcwidth` and East Asian Width alone are insufficient.
6. **Collection scaling:** start with simple rows and benchmark; add a lazy row source only if creating offscreen elements is materially expensive.
7. **Theme ownership:** establish a semantic palette and a small `Theme` override without implicit global styling rules.
8. **Feature negotiation:** revisit terminfo or Kitty keyboard only when primary terminal tests show a tangible gap.
9. **Ctrl-Z suspension:** postpone until a full restore-before-suspend/reacquire-after-continue sequence is tested.

## 17. Final recommendation and acceptance contract

Build **TerminalUI as a component toolkit with a minimal terminal engine**, not as a drawing API with a few optional helpers. Keep the terminal and text foundations from the earlier research, but ensure the public development experience is substantially higher-level.

The first implementation should prove this exact flow:

```text
NotesApp / WorksheetDemo state
  → compose Element.column / Panel / List / TextEditor / Dialog
  → TerminalHost measures layout and dispatches focus/keys
  → app receives UIAction and updates its own values
  → rebuild current element tree
  → paint cell grid and flush frame diff to macOS/Omarchy terminal
```

This avoids both external TUI framework dependencies and overdesigning a generic SwiftUI clone. `TerminalUI` remains independent of Parallax, while the chosen component vocabulary is proven against real Parallax-shaped interactions.

**Definition of done:** an application author spends ordinary development time expressing **screen content, structure and meaning**—not inventing how a button, list, dialog, scroll view or text editor works. Cross-platform terminal protocol complexity remains a private implementation concern.

## References and verification notes

Primary and official references consulted (accessed 31 October 2026):

1. [Omarchy terminal manual](https://omarchy.org/manual/terminal/) — current default and supported terminal choices.
2. [Omarchy terminal selector source](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-default-terminal) — recognised alternatives; version-specific implementation.
3. [SwiftPM standalone package guide](https://developer.apple.com/documentation/xcode/creating-a-standalone-swift-package-with-xcode) and [Swift build guide](https://www.swift.org/documentation/server/guides/building.html) — cross-platform Swift packages.
4. [Swift 6.2 release notes](https://www.swift.org/blog/swift-6.2-released/) and [Swift 6.4 release](https://www.swift.org/blog/swift-6.4-released/) — contemporary language/toolchain context.
5. [Linux `termios`](https://www.man7.org/linux/man-pages/man3/termios.3.html) — raw/noncanonical modes and signals.
6. [Linux `TIOCGWINSZ`](https://man7.org/linux/man-pages/man2/TIOCGWINSZ.2const.html) — terminal size.
7. [Linux `signal-safety`](https://man7.org/linux/man-pages/man7/signal-safety.7.html) — safe work from signal handlers.
8. [Linux `poll`](https://man7.org/linux/man-pages/man2/poll.2.html) — readiness-driven I/O alternative.
9. [Xterm control sequences](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html) — alternate screen, paste, SGR and cursor addressing.
10. [Terminfo](https://man7.org/linux/man-pages/man5/terminfo.5.html) — alternative capability lookup.
11. [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/) — extended keys and negotiation.
12. [Unicode UAX #29](https://www.unicode.org/reports/tr29/) and [UAX #11](https://www.unicode.org/reports/tr11/) — segmentation and width limitations.
13. [tmux terminal feature source](https://github.com/tmux/tmux/blob/master/tty-features.c) and [FAQ](https://github.com/tmux/tmux/wiki/FAQ) — feature mediation and passthrough.
14. [NO_COLOR](https://no-color.org/) — colour preference.
15. [Ratatui terminal rendering reference](https://docs.rs/ratatui/latest/ratatui/struct.Terminal.html) — cell-grid/diff precedent, not a runtime dependency.
16. [Bubble Tea repository](https://github.com/charmbracelet/bubbletea) — event/update/view precedent, not a dependency.
17. [Terminal Unicode Core proposal](https://github.com/contour-terminal/terminal-unicode-core) — evolving text-width ideas, not adopted as a fixed standard.
18. [Swift concurrency documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) — actor isolation and main actor.

**Verification limitations:** No interactive macOS or Foot test could be performed in this research workspace. No versioned Foot/macOS Terminal compatibility claim should be interpreted as verified beyond referenced documentation. The local Linux experiment was limited to compilation and noninteractive execution; it did not validate visual terminal behaviour. Package interfaces are architecture-level proposals, not an implemented or compiled public library.

Additional component/API references (added in v2):

19. [Ratatui built-in widgets](https://docs.rs/ratatui/latest/ratatui/widgets/) and [layout](https://www.ratatui.rs/concepts/layout/) — component vocabulary and external widget state; architectural precedent only.
20. [Charm Bubbles](https://github.com/charmbracelet/bubbles) — standard text input, textarea, table and list behaviour; precedent only.
21. [Textual widget guide](https://github.com/Textualize/textual/blob/main/docs/guide/widgets.md) — focus and key dispatch precedent.
22. [SwiftUI state guidance](https://developer.apple.com/documentation/swiftui/managing-user-interface-state) — distinction between view-local and shared/application state; conceptual precedent only.
