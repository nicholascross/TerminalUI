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
            Button("Quit", id: "quit").onActivate { application.stop() }
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

`.onSubmit`, `.onActivate` and `.onDismiss` register current callbacks; `.onAction` consumes otherwise unclaimed actions when it returns true. Inputs and callback captures refresh while matched components retain their slots. Enter submits configured editors; Shift+Enter and paste remain multiline data. Input barriers resolve state changes before the next event in a batch.

Transactions defer resolution and terminal output, while reads see writes immediately. Throwing from a transaction still schedules applied changes. A coalesced wakeup also renders background updates while the terminal is idle. State mutation during body evaluation, lowering, measurement or drawing is rejected.

## Identity, focus and reveal

Identity combines the mounted parent, concrete component type, structural slots, branch discriminators and collection keys. Two same-type conditional branches have separate lifetimes; one component with changing input preserves its lifetime. Optional siblings do not shift later fixed slots. `ForEach` keys are local to their repetition scope; duplicate keys within a collection are invalid, while equal keys in different collections are independent.

Removal releases state, subscriptions and callback registrations. Reappearance starts a new generation. `.visible(false)` retains state. Detached bindings, callbacks and handles never reconnect to replacement generations. Component state is independent of the engine's bounded retention of inactive caret/viewport mechanics.

`.id(value)` accepts a stable `Hashable` value, resets the modified subtree when the value changes, and registers a reveal target. ID equality preserves the concrete ID type. IDs do not override parent/branch scopes or become control IDs. Engine `Element.id(String)` remains reveal-only.

`Component(view, key:)` is an explicit keyed component boundary; ordinary views need no wrapper. Context focus paths list component/item keys. `.scope(value)` names a lookup scope without making its changing name an identity reset:

```swift
Column {
    ForEach(leftItems, id: \.id) { item in Editor(item: item).id(item.id) }.scope("left")
    ForEach(rightItems, id: \.id) { item in Editor(item: item).id(item.id) }.scope("right")
}
```

From an installed context, use `application.scope("left")`, then `application.focusTarget(path: [itemID], id: "draft", in: scope)`, `application.focus(target)`, or `application.reveal(itemID, in: scope)`. Scopes and focus handles are opaque and generation-scoped. Ambiguous scope names, key paths and reveal IDs diagnose and fail. Absent/hidden reveal targets fail without retaining a request. Revealing an unchanged ID preserves state and reveals through nested enclosing scroll containers.

`.onFocusChange` observes focus outside evaluation and may update state. Contexts reference their presentation weakly; after release, lookups fail and stop is harmless.

## Testing and explicit engine integration

`ApplicationHarness(root:)` drives the real host and mounted runtime without a TTY. Use `preview`, `send(KeyEvent)`, `send(TerminalEvent)`, `context`, `focusedTarget`, `metrics`, `hasPendingUpdates`, `invalidate`, `transaction` and `unmount`. It neither returns elements nor accepts raw presentation services. Metrics distinguish state writes, scheduled flushes, evaluations, reconciliations, mounts and unmounts.

Use `EngineContent(element)` from `TerminalUIBridge` to embed raw content. `ViewPresentation(root:)` implements the engine presentation-source contract for an engine-owned host. Import both entry points explicitly and qualify overlapping control names. The bridge also enables raw `Element` values as view bodies and `engineElement(view)` for deferred mixed composition. Resolve presentations before passing their elements to a renderer.

LayoutDemo demonstrates a state-owned value model, shared bindings, an independent command draft, modal commands and focus-driven navigation. The compiled external consumer adds helper views, a generic container, explicitly typed bodies, conditionals and both loop forms. Tests and PTY scripts are listed in the [README](../README.md).
