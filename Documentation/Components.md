# Views and mounted state

`TerminalUI` owns the declarative application API. Import it for concrete controls, generic containers, `@ViewBuilder`, state, bindings and application services. Engine operations require an explicit `TerminalUIEngine` import; mixing the APIs also requires `TerminalUIBridge`.

## Applications and previews

```swift
import TerminalUI

@main
@TerminalApplication
struct NotesApp {
    var root: some TerminalView { Workspace() }
    var theme: Theme { .dusk() }
    var configuration: TerminalConfiguration { .init(mouseEnabled: true) }
}

@TerminalComponent
struct Workspace: TerminalView {
    @State private var draft = ""
    @ApplicationContext private var application

    var body: some TerminalView {
        Column {
            TextEditor(id: "draft", text: $draft).onSubmit { draft = "" }
            Button("Quit").onActivate { application.stop() }
        }
    }
}
```

Only the root is required. The application macro supplies conformance, main-actor isolation and `main()`. Keep `@main` explicit. Definitions must support `Self()` with no arguments. `--preview` prints a snapshot without opening a terminal. `TerminalApp(root:configuration:theme:)` offers `run`, `preview`, `context`, `invalidate`, `transaction` and `stop`; host and presentation storage are package implementation details.

`TerminalView` has an associated `Body: TerminalView`. Opaque bodies preserve concrete composition types. Explicit types also work: `var body: Text { return Text("Ready") }`. Generic containers store a `Content: TerminalView` constructed by a `@ViewBuilder` closure. Primitive controls use `Body == Never`; normal resolution never reads their `body`. Application views need no rendering hooks.

The builder preserves fixed slots, branches, optional content and repetitions. Ordinary `for` loops use positional identity; use `ForEach` for keyed collections. Parameter-pack tuples have no fixed child-count limit. `AnyTerminalView` provides deliberate heterogeneous storage and availability erasure; normal composition remains generic.

## State and bindings

`@TerminalComponent` registers private `@State` and `@ApplicationContext` properties before evaluation. State initializers run once per mount generation. Recreated views reconnect to authoritative typed slots. The public installation support exists for external macro expansions; it is compiler support, not an application service.

State writes are synchronous. Equal `Equatable` assignments suppress updates. Writes through bindings and captured callbacks follow the same rules. `Binding(get:set:)` supports normalization, `Binding.constant` ignores writes, and writable key-path projection supports value models such as `$model.title`. Reference objects are not automatically observed: replace their stored value or invalidate the application when needed.

Bound overloads cover text fields/editors, lists, tables, tabs, menus and menu bars. `@Binding` lets an extracted view consume an owner's binding. Primitive binding reads occur during lowering under the current component's dependency scope. Child bodies remain deferred, so a child-only write does not evaluate unrelated bodies. Dependencies are replaced on every evaluation.

`Menu(id:title:items:initialSelection:)` owns its search text and highlighted selection by default. `initialSelection` seeds the selection once per mounted lifetime; removing and recreating the menu resets its local state. Use the query/selection binding overload when that state needs to be shared or retained by a parent. The value overload leaves text and selection actions for the caller to handle. A menu's `.onDismiss` handles both Escape and its built-in Return button.

`MenuBar` owns its keyboard highlight when `focusedItem` is omitted; `selection` still marks the application's current destination. Supply a `focusedItem` binding to share the highlight, or an explicit optional value to handle selection actions yourself. `List` and `Table` also keep selection locally when `selection` is omitted, with an optional `initialSelection` seed. Existing value and binding overloads remain available. Use bindings when another view needs the selected value, as the layout demo's inspector does.

Buttons need no explicit ID when using callbacks. Anonymous buttons receive stable mounted addresses, including within keyed collections. Supply `id:` for programmatic focus or named actions. `.keyboardShortcut(.controlP)` activates a button anywhere in the active workspace or dialog scope; hidden and disabled buttons do not participate. Modified shortcuts follow the menu routing policy, so typing, paste, Tab and Escape retain their normal meanings.

`Menu` and `MenuBar` accept arrays of identifiable values. Conform to `MenuItemDefinition` to supply a title and an optional shortcut preference. For hashable values, activation focuses the matching `.focusTarget(value)` by default:

```swift
enum Pane: String, CaseIterable, MenuItemDefinition {
    case topics, inspector
    var id: Self { self }
    var title: String { self == .topics ? "Topics" : "Inspector" }
}

MenuBar(id: "navigation", items: Pane.allCases,
        activeItem: application.focusedValue(of: Pane.self))
```

`activeItem` marks the current destination separately from keyboard highlight. Highlight follows item identity across collection reorder; values and callback captures refresh with the view. Typed `Menu` initializers also accept `items:` and a typed `initialSelection:`, retaining local search and highlight until dismissal.

Supply an explicit activation closure for non-focus actions such as save, refresh or quit. It receives the typed item and replaces default focus; non-hashable identifiable values also use this explicit callback path. `.onActivate { ... }` on a collection menu observes accepted activation before its default focus action or custom callback. Observers run in modifier order and do not replace the action. For a modal, use `.onActivate { commandsOpen = false }` to dismiss before default focus moves to a background target. Escape and the Return button use `.onDismiss`, without firing activation observers. Unavailable entries do not fire activation observers.

`menuShortcut` defaults to `.automatic`: entries at original array positions 1–9 receive those access keys, and later entries have no automatic key. Return `.key("t")` to override an item's key or `.none` to opt out. Collisions take the first matching item in collection order, without errors or reassignment. Menu bars accept access keys while focused and their Alt/Control variants elsewhere in the active scope. Searchable menus accept only local access keys with an empty query; filtering preserves the original numbered labels. Unavailable first matches consume without falling through.

Conformance is optional. Supply `itemTitle:` and optionally `shortcut:` closures for existing `Identifiable` types. Those closures can also override conforming values for one presentation, for example `itemTitle: { "Focus \($0.title)" }`. Use `unavailableReason:` to leave an entry inspectable without allowing activation. Existing low-level `MenuItem` value and binding overloads remain available; `MenuAction` and its result builder have been replaced by the collection API.

`.onSubmit`, `.onActivate` and `.onDismiss` register current callbacks; `.onAction` consumes otherwise unclaimed actions when it returns true. Inputs and callback captures refresh while matched components retain their slots. Enter submits configured editors; Shift+Enter and paste remain multiline data. Input barriers resolve state changes before the next event in a batch.

Transactions defer resolution and terminal output, while reads see writes immediately. Throwing from a transaction still schedules applied changes. A coalesced wakeup also renders background updates while the terminal is idle. State mutation during body evaluation, lowering, measurement or drawing is rejected.

## Identity, focus and reveal

Views mount automatically. Identity combines the mounted parent, concrete component type, structural slots, branch discriminators and explicit view/item IDs. Two same-type conditional branches have separate lifetimes; one component with changing input preserves its lifetime. Optional siblings do not shift later fixed slots. `ForEach` IDs are local to their repetition scope; duplicate IDs within a collection are invalid, while equal IDs in different collections are independent.

Removal releases state, subscriptions and callback registrations. Reappearance starts a new generation. `.visible(false)` retains state. Detached bindings, callbacks and handles never reconnect to replacement generations. Component state is independent of the engine's bounded retention of inactive caret/viewport mechanics.

`.id(value)` accepts a stable `Hashable` value, resets the modified subtree when the value changes, and identifies it for focus paths and reveal. `ForEach` item IDs also identify their subtrees for focus and reveal; no extra `.id(item.id)` is needed. ID equality preserves the concrete value type, including through `AnyHashable` erasure. IDs do not override parent/branch scopes or become control IDs. Engine `Element.id(String)` remains reveal-only.

Context focus paths list view/item IDs. Unidentified views are transparent to lookup; every identified subtree on the way to the control needs a path entry. For example, `Workspace().id("workspace")` containing `Editor().id("editor")` is addressed with `application.focusTarget(path: ["workspace", "editor"], id: "draft")`. The final `id:` is the local control ID. There is no separate public component/key API.

`.scope(value)` names a lookup region without making its changing name an identity reset. Use scopes to disambiguate repeated view/item IDs:

```swift
Column {
    ForEach(leftItems, id: \.id) { item in Editor(item: item) }.scope("left")
    ForEach(rightItems, id: \.id) { item in Editor(item: item) }.scope("right")
}
```

From an installed context, use `application.scope("left")`, then `application.focusTarget(path: [itemID], id: "draft", in: scope)`, `application.focus(target)`, or `application.reveal(itemID, in: scope)`. Scopes and focus handles are opaque and generation-scoped. Ambiguous scope names, ID paths and reveal IDs diagnose and fail. Absent/hidden reveal targets fail without retaining a request. Revealing an unchanged ID preserves state and reveals through nested enclosing scroll containers.

Register typed destinations on their controls to avoid coupling focus requests to view paths:

```swift
TextEditor(id: "draft", text: $draft)
    .focusTarget(Pane.command)

application.focus(Pane.command)
```

Values retain their concrete type, including through `AnyHashable` erasure. `application.focusTarget(Pane.command)` returns the existing opaque handle when needed. Repeated destinations in separate workspaces can be addressed with `application.focus(Pane.command, in: workspaceScope)` using a mounted `.scope(...)`. Ambiguous unscoped destinations diagnose and fail, following existing focus-lookup rules. Registrations disappear on removal, and stale handles or scopes never reconnect to replacement generations. Hidden or disabled controls cannot receive focus; an active dialog blocks requests to background controls.

Read `application.focusedValue(of: Pane.self)` for the actual typed focus, optionally `in: workspaceScope`. Reads during view evaluation subscribe that view to focus changes; there is no need to mirror focus in application state. The value is read-only and returns `nil` when actual focus is outside the requested type or scope.

Use `.onFocusChange(of: Pane.self) { ... }` for effects such as updating a status message. It observes actual typed focus in the modified subtree, including keyboard, pointer and context requests. It reports the initial value and subsequent changes, with `nil` when focus is outside that subtree's registered destinations of the requested type. Registration changes are reflected even when the underlying control handle stays the same; unrelated renders do not repeat notifications. Callbacks run outside evaluation and may update state. The original `.onFocusChange` overload continues to report opaque focus handles. Contexts reference their presentation weakly; after release, lookups fail and stop is harmless.

Apply `.initialFocus()` to a control to prefer it when the screen or a modal first opens. Hidden and disabled controls are skipped; the first eligible preference wins. Updates preserve subsequent keyboard, pointer and programmatic focus, and dismissing a modal restores its opener. The layout demo marks the Topics list, so keyboard exploration starts in the workspace.

## Testing and explicit engine integration

`ApplicationHarness(root:)` drives the real host and mounted runtime without a TTY. Use `preview`, `send(KeyEvent)`, `send(TerminalEvent)`, `context`, `focusedTarget`, `metrics`, `hasPendingUpdates`, `invalidate`, `transaction` and `unmount`. It neither returns elements nor accepts raw presentation services. Metrics distinguish state writes, scheduled flushes, evaluations, reconciliations, mounts and unmounts.

Use `EngineContent(element)` from `TerminalUIBridge` to embed raw content. `ViewPresentation(root:)` implements the engine presentation-source contract for an engine-owned host. Import both entry points explicitly and qualify overlapping control names. The bridge also enables raw `Element` values as view bodies and `engineElement(view)` for deferred mixed composition. Resolve presentations before passing their elements to a renderer.

LayoutDemo demonstrates a state-owned value model, shared bindings, an independent command draft, modal commands and focus-driven navigation. The compiled external consumer adds helper views, a generic container, explicitly typed bodies, conditionals and both loop forms. Tests and PTY scripts are listed in the [README](../README.md).
