# Components and mounted state

`TerminalUIComponents` is an optional product that re-exports `TerminalUILayout`. Existing `TerminalApplication`, controlled-value controls and array-based layouts remain supported. The component product adds declarative applications, struct views, mounted state, bindings and scheduled updates.

## Declarative applications

Use `@main` and `@TerminalApplication` on a struct to declare the root screen. The macro supplies `static main() async throws`, main-actor isolation for application members and conformance to `TerminalApplicationDefinition`:

```swift
import TerminalUIComponents

@main
@TerminalApplication
struct MyApp {
    var root: some TerminalView { Workspace() }
    var theme: Theme { .dusk() }
    var configuration: TerminalConfiguration { .init(mouseEnabled: true) }
}
```

Only `root` is required. Omitted settings use `Theme()` and `TerminalConfiguration()`; mouse input stays disabled by default. The entry point constructs the definition with `Self()`, so stored application properties must have defaults or an initializer callable without arguments. Keep `@main` explicit on the executable's entry type. The `@TerminalApplication` macro and the existing `TerminalApplication` protocol occupy different usage contexts; legacy application conformances continue to work.

The generated method delegates to `TerminalApp`, which owns the host and mounted presentation and connects their services. `--preview` prints an 80×24 plain-text snapshot without opening a TTY. Application-specific flags remain in the definition; LayoutDemo checks `--no-mouse` in its configuration.

For tests and embedding, use `MyApp().makeApplication()` or `TerminalApp(root: Workspace())`. The runner exposes `host`, `presentation`, `context`, `run()` and `preview(width:height:)`. Construction connects services without evaluating component bodies. Previews use the host's theme and current focus and do not write terminal output. Each call to `makeApplication()` creates an independent mounted tree.

Mounted screens access lifecycle and focus services without constructor wiring:

```swift
@TerminalComponent
struct ApplicationControls: TerminalView {
    @ApplicationContext private var application

    var body: Element {
        Button("Quit", id: "quit").onActivate { application.stop() }
    }
}
```

`@TerminalComponent` installs `@ApplicationContext` alongside `@State`. The context offers `focusTarget(path:id:)`, `focus(_:)`, `keepVisible(_:)` and `stop()`, scoped to the containing presentation. Focus targets retain the existing explicit-key path and generation semantics. Contexts reference the presentation weakly; after it is released, lookups return nil and focus requests return false. Standalone `ComponentApplication` harnesses can inject `PresentationServices`, including a `stop:` callback. `TerminalHost.connect(_:)` connects services before a run without acquiring a TTY.

## Components

```swift
import TerminalUIComponents

@TerminalComponent
struct CommandPane: TerminalView {
    @State private var draft = ""
    let submit: (String) -> Void

    var body: Element {
        Panel("Command") {
            TextEditor(id: "draft", text: $draft)
                .onSubmit { submit(draft); draft = "" }
        }.height(.fit(maximum: 8))
    }
}

struct Workspace: TerminalView {
    var body: Element {
        Column {
            Text("Workspace")
            Component(CommandPane(submit: { print($0) }), key: "command")
        }
    }
}
```

`TerminalView` is a main-actor protocol with an `Element` body. Stateless views need no macro. A view expression inside `ElementBuilder` inserts an unkeyed component boundary; `Component(_:key:)` makes its identity explicit. Bodies stay unevaluated until a `ComponentApplication` mounts them.

```swift
@MainActor
func runWorkspace() async throws {
    let source = ComponentApplication(root: Workspace())
    try await TerminalHost().run(source)
}
```

Use `source.resolve()` to obtain ordinary, resolved elements for `UIEngine` tests and previews. Passing an unresolved component to the ordinary renderer is a programming error. `Examples/ComponentConsumer/Consumer.swift` is a compiled example of this API outside the package access boundary. Run it with `swift run ComponentConsumer`, or use `swift run ComponentConsumer --preview` for a terminal-independent snapshot. It shows two independent command editors; Tab moves focus, Enter submits and clears a draft, and Ctrl-C or the Quit button exits.

## State and bindings

`@TerminalComponent` generates `_installState(_:)`, connecting each backing `@State` and `@ApplicationContext` wrapper using its declaration name, including private declarations. Its SwiftSyntax 603.0.0 dependency is build-time tooling matched to the package's Swift 6.3 toolchain. The ordinary facade and layout products do not depend on the macro target.

State initializers run once per mount. Recreated values reconnect before their bodies run. State setters update synchronously, including writes through captured view values and bindings. Equal assignments to `Equatable` values do not schedule work; other assignments invalidate subscribers. Mutating a reference object's properties does not observe that object automatically. Replace the stored value or explicitly invalidate the source for external model changes.

A binding is also a property wrapper:

```swift
struct FilterField: TerminalView {
    @Binding var filter: String
    var body: Element { TextField(id: "filter", text: $filter) }
}
```

An owning component passes `$filter` to that initializer. `Binding(get:set:)` supports custom validation/normalization, and `Binding.constant(_:)` ignores writes. Writable key-path projection supports value view models: `$model.title` reads and writes `title` through the model's storage boundary. A custom setter is invoked once per action and its authoritative value is read on resolution.

Bound factory overloads include `TextField`, `TextEditor`, `List`, `Table`, `Tabs`, `Menu`, and `MenuBar`. Selection overloads support both `Binding<String?>` and, for lists/tables/tabs, `Binding<String>`. The existing `value:` and ordinary `selection:` overloads are unchanged. `.onSubmit {}`, `.onActivate {}`, and `.onDismiss {}` register one current callback per event. `.onAction { action in ... }` handles otherwise unclaimed actions in the owning scope; return `true` to consume an action.

The routers still emit `UIAction`. A bound action is consumed once; it is not also delivered to legacy application handling. Enter submits an editor with `.onSubmit`, Shift+Enter inserts a newline, and paste remains data.

## Identity and focus

A component's identity combines its owning parent, type and explicit key or structural slot. `ForEach(items, id: \.id) { item in ... }` supplies keyed boundaries and accepts either views or elements. Reorder preserves keyed state and retained layout nodes. Duplicate keys beneath one owner are invalid and produce a diagnostic. Keys for different conditional instances must be distinct; the flattened builder does not infer branch identities.

Removal or a change of type/key unmounts the old generation and releases state/subscriptions/callback registrations. Re-adding starts fresh. `.visible(false)` retains a mounted component's state. Old bindings/callbacks cannot change a replacement generation. Writes to detached state are ignored and diagnosed in debug builds. Mutation during body evaluation, measurement or custom-widget painting is rejected.

Local control IDs and `.id(...)` reveal IDs are translated beneath the mounted generation. Two editors may both use `id: "draft"`. Literal IDs outside component scopes retain their legacy meaning. Use an explicit focus handle rather than a local string:

```swift
@MainActor
func focusCommand(host: TerminalHost, source: ComponentApplication) {
    if let target = source.focusTarget(path: ["command"], id: "draft") {
        host.focus(target, in: source)
        source.keepVisible(target)
    }
}
```

`host.focusedTarget` exposes current focus as an opaque handle. `.onFocusChange { target in ... }` observes host focus changes and may update component state. The host delivers callbacks outside body evaluation and resolves their changes before painting or dispatching subsequent input. Presentation sources without component observers retain the default no-op behavior.

The path starts at the root view and lists explicit component keys. The root itself is implicit. For a legacy adapter the path starts in the legacy tree. Handles carry the mount generation and stop matching after replacement. `source.focus(_:)` uses the currently connected host service; `host.focus(_:in:)` can be used directly before running the host.

## Scheduling and selective resolution

Writes mark subscribed bodies dirty and schedule one update wakeup for a burst. A dedicated descriptor wakes an idle terminal independently of process signals. `ComponentApplication` accepts an injected `schedule:` closure and `diagnostic:` sink for deterministic tests. `resolve()` is an explicit consistency barrier for terminal-independent consumers.

```swift
@MainActor
func rename(source: ComponentApplication, title: Binding<String>, status: Binding<String>) {
    source.transaction {
        title.wrappedValue = "New name"
        status.wrappedValue = "Renamed"
    }
}
```

Transactions defer resolution/output, not writes. Reads inside the handler see the latest values. Throwing exits close the scope and schedule applied changes. Bodies record slot reads; reading a parent binding from a child subscribes the child. Dependencies are replaced on each body evaluation. Newly supplied inputs always reevaluate a child, including fresh callback captures.

The host resolves changes before the next input event and prepares pointer geometry when needed. Typing `a`, then `b`, then Enter in one input read therefore submits `ab`. Interaction barriers may evaluate bodies several times before one terminal frame. Child-only changes update cached ancestor output paths without calling unaffected ancestor bodies. Boundary revisions let layout skip untouched subtrees while invalidating ancestor measurements when size changes. Existing scroll repainting and full visible-grid comparison remain in use.

`source.metrics` reports actual state writes, scheduled flushes, body evaluations and component reconciliations. `engine.metrics` reports retained reconciliation, measurement, painting and frame counts; `host.frameWriteCount` counts transmitted frame transactions. These are separate measurements, not promises of widget-only layout or painting.

## Incremental migration and the demo

Wrap an existing application with `ComponentApplication(legacy: app)` and pass the adapter to `host.run`. Its `view()` can return ordinary elements mixed with `Component` values. Component state changes reuse the mounted legacy output. `host.invalidate()` or `source.invalidate()` conservatively rebuilds the root. Unclaimed actions are translated back to local IDs and forwarded to the legacy handler.

LayoutDemo uses a value `LayoutViewModel` stored in `LayoutScreen`'s `@State`. The model owns shared presentation state and commands. `WorkspaceView` shares topic selection with `TopicsView` and `InspectorView` through `@Binding`; `CommandPane` owns its draft locally. `CommandMenu` owns search/selection state. `Pane` supplies typed destinations and component keys. `LayoutNavigation` translates those destinations to scoped focus handles using the screen's `@ApplicationContext`; focus notifications update the screen's view model, keeping toolbar selection current for shortcuts, Tab, pointer input and modal restoration. The executable in `Examples/LayoutDemoRunner` declares its root, theme and configuration with `@main @TerminalApplication`. There is no application-owned assembly initializer or connection step. Reusable demo code is in `LayoutDemoSupport` so tests can import it and construct `TerminalApp(root: LayoutScreen(), ...)` directly.

## Validation

Run after building:

```sh
swift test -j 4
bash Scripts/test-terminalui-components-consumer.sh
python3 Scripts/test-terminalui-components-pty.py
python3 Scripts/test-terminalui-layout-pty.py
python3 Scripts/test-terminalui-layout-pty.py --no-mouse
python3 Scripts/test-terminalui-pty.py
```

The compiler check uses an external module without package access. Macro expansion tests exercise private registration and invalid declarations. Component tests cover keyed lifetime, stale writes, dynamic dependencies, selection bindings, normalization, input barriers, transactions and awaited output. A reference comparison checks incremental frames against conservative root reevaluation through edits, Unicode, reorder and resize. The component PTY consumer verifies an idle background write, two independent editors with the same local ID, batched input and terminal restoration.

A representative debug run on Linux with 200 keyed editors and 40 edits at 80×24 took 0.148 seconds: 40 additional bodies, 160 retained-node reconciliations, 280 measurements and 2,920 paints. The legacy root ran once and the untouched last editor ran once. The test reports measurements without machine-dependent timing thresholds.
