# Component and state architecture migration

Status: implemented (2026-11-15). The existing negotiated layout module remains the foundation. The sections below retain the design and acceptance criteria; see [Components.md](../../Components.md) for the delivered API and validation commands. The implementation includes the optional product, macro-generated private-state registration, scoped bindings/callbacks, scheduled transactions and update wakeups, dependency-driven resolution, retained boundaries, and the cleaned-up LayoutDemo with its view model.

## Outcome

Add an optional component layer with four capabilities:

1. Struct components describe their interface through `body`.
2. Local state belongs to a mounted component identity and survives recreation of its struct value.
3. Bindings connect editors and selections directly to that state.
4. Scheduled updates batch mutations and ultimately evaluate only affected component bodies.

Existing `Element`, array-based layouts, negotiated layouts, `TerminalApplication`, actions and terminal hosting remain supported. Migration is incremental: a component can contain ordinary elements, and an existing application can host a component subtree. Terminal resources, retained component records and layout nodes remain reference types internally.

This extends the original MVP's deliberate deferral of component state and property wrappers. The new functionality belongs to an optional layer rather than changing the meaning of the existing element API.

## Current implementation and required changes

| Current behavior | Required change |
| --- | --- |
| `TerminalApplication: AnyObject` combines mutable state, `view()` and action handling. | Keep it as the lower-level application API; add a struct component protocol and an adapter. |
| `Column`, `Row` and other factories eagerly return `Element` values. | Keep the factories; preserve component descriptors as unevaluated nodes until the component runtime mounts them. |
| `ElementBuilder` collects `[Element]` and loses function/component boundaries. | Add a component expression overload that inserts a boundary, rather than evaluating `body` in the builder. |
| Application text and selected IDs are plain controlled values. | Add binding overloads that still resolve into the same built-in controls. |
| `TerminalHost.invalidate()` coalesces flags; actions conservatively rebuild the application view. | Introduce a presentation/update source supporting tracked state and scheduled invalidation alongside the legacy adapter. |
| `LayoutNode.update` reconciles descendants positionally. | Recognize component identity/revision boundaries and skip unchanged resolved subtrees; retain keyed component nodes across reorder. |
| `WidgetStateStore` retains caret, viewport and focus-related data. | Keep it responsible for widget mechanics; introduce separate storage for component-owned application state. |

The existing host tests explicitly require fresh values between input events: typing `a` and `b` in one input batch must produce `ab`. The new scheduler must preserve this behavior while reducing redundant work.

## Proposed developer API

```swift
import TerminalUIComponents

@TerminalComponent
struct CommandPane: TerminalView {
    @State private var draft = ""
    let submit: (String) -> Void

    var body: Element {
        Panel("Command") {
            TextEditor(id: "draft", text: $draft)
                .onSubmit {
                    submit(draft)
                    draft = ""
                }
        }
        .height(.fit(maximum: 8))
    }
}

struct Workspace: TerminalView {
    let send: (String) -> Void

    var body: Element {
        Column(spacing: 1) {
            Text("Workspace").role(.heading)
            Component(CommandPane(submit: send), key: "command")
        }
    }
}
```

`TerminalView` is `@MainActor` with a `body: Element` requirement. It does not inherit from `AnyObject`. Its composition adapter retains a typed component value behind an internal descriptor. `Component(_:key:)` returns an `Element` containing that descriptor, preserving its boundary. The builder can also accept a `TerminalView` expression directly and insert the equivalent boundary; the explicit factory supplies keys and makes identity visible where useful.

Keep `body` returning `Element` initially. Existing factories, modifiers and component functions already compose with it; an associated `Body` type and a generic hierarchy of primitive view structs are unnecessary for these objectives.

`@TerminalComponent` generates state-installation metadata for stateful structs. Stateless structs need only conform to `TerminalView`. The macro is limited to persistent-property registration and diagnostics; it does not generate layout, event loops or application logic.

The names `State` and `Binding` are owned by `TerminalUIComponents`; clients importing SwiftUI as well can qualify them by module.

Mount through an explicit adapter, for example `ComponentApplication(root: Workspace(send: send))`, passed to the host's presentation-source overload. For mixed migration, `ComponentApplication(legacy: existingApp)` resolves component descriptors inside the legacy application's returned tree and forwards unclaimed actions to its `handle(_:)`. Component-only state updates reuse the mounted legacy output; explicit root invalidation calls the legacy `view()` again and reconciles component identities. Raw unresolved component descriptors must be resolved by this adapter or a terminal-independent component test harness before reaching `UIEngine`; the ordinary renderer does not evaluate arbitrary user bodies.

## Module boundaries

| Target/product | Ownership and dependencies |
| --- | --- |
| `TerminalUICore` | Small presentation, component-boundary and behavior contracts expressed using existing elements/actions. No dependency on the optional component layer. |
| `TerminalUIComponentRuntime` — internal target | Mounted component records, state slots, dependency reads, scoped action registrations and dirty-component resolution. Depends on Core. |
| `TerminalUIComponents` — optional public product | `TerminalView`, `Component`, `State`, `Binding`, keyed repetition, bound-control overloads and the host/application adapter. Depends on Layout, ComponentRuntime and the macro declarations/implementation as appropriate. |
| `TerminalUIComponentMacros` — compiler plugin | Synthesizes state-property descriptors and installation code using SwiftSyntax matched to the package's Swift toolchain. No dependency on terminal I/O or rendering. |
| `TerminalUIRuntime` | Continues to own terminal sessions, input/output scheduling and frame delivery. Consumes the Core presentation contract, not the optional public component product. |
| `TerminalUILayoutEngine` / Rendering | Continue to own measurements, geometry, clipping, focus reveal and painting. Understand transparent resolved component boundaries and their revisions. |

The optional component product re-exports `TerminalUILayout`, which already exposes the existing controls and facade. There is no dependency from Core, LayoutEngine or Rendering back to Components. Macro use and state machinery do not become requirements for applications using only `TerminalUI` or `TerminalUILayout`.

The component runtime operates against a small injected Core service interface for focus/reveal requests and invalidation. It never reaches into `TerminalHost` or private renderer state. The host accepts a Core-owned presentation source; a legacy adapter implements that source for `TerminalApplication`, while the component adapter implements it for a mounted root. The component adapter can also embed its resolved root in an existing application and forward unclaimed actions there.

Implement our state and binding contracts in portable Swift, retaining the package's existing platform minimums. System Observation integration for external model objects can be an optional follow-up; it is not required for the four objectives.

## Component identity and lifecycle

Identity consists of the owning parent identity, a local key and the component type. Each mount also has a generation token. Runtime identity is independent of struct object addresses, current property values, layout-node addresses and the position of a keyed item in an array.

- An unkeyed component gets a structural slot within its parent. Inserting/reordering unkeyed peers can replace their identities; stable repeated content must use explicit keys.
- Add keyed repetition, for example `ForEach(items, id: \.id) { item in ... }`. Items keep their component records and state across reorder.
- Conditional branches containing different logical instances of the same component type must have distinct keys. The flattened existing builder cannot reproduce SwiftUI's compiler-derived branch identity, so this requirement is explicit.
- Duplicate sibling keys are diagnosed as an invalid component tree; they must never silently share state.
- Recreating the same component type/key refreshes its input values and callbacks while retaining its state slots.
- Changing the type/key or removing a component unmounts it and releases its component state, subscriptions and action registrations. Re-adding it starts a new generation.
- Applying `.visible(false)` to a component still present in the mounted graph retains its state. Removing it with an `if` unmounts it. A parent chooses whether an inactive tab remains mounted.
- Existing `.id(...)` remains a reveal identifier. Component keys use a separate API and identity namespace.

Scope component-local control IDs beneath the mounted owner. Two `CommandPane` instances may both contain `id: "draft"` without sharing caret, viewport, bindings or focus identity. Translate them to engine IDs internally. Preserve literal global IDs for legacy elements outside component scopes. Introduce an explicit scoped focus target/handle for navigation into a component; do not make `host.focus("draft", ...)` guess between owners.

Component lifetime differs from the widget store's bounded inactive retention. Unmounted component state is released at commit rather than kept in the 256-entry widget cache. Generation-scoped control IDs prevent an old widget cache entry from reviving a new component's transient state.

## Persistent state implementation

`@State<Value>` holds an initial-value factory and an installed reference to a typed runtime slot. The slot is addressed by component identity plus a stable declaration key, with its value type checked on installation. Initialize it once per mount. Recreated component structs reconnect their wrappers to the existing slots before `body` runs.

The macro generates an installation method that binds each backing wrapper using its declared property name. This avoids relying on reflection, property enumeration order, memory offsets or an ambient global mount context. It also makes the operation possible for private properties without manual application boilerplate. Renaming a state declaration changes that declaration's storage key.

Provide a narrow, public implementation-support contract for macro-generated installation, with a default no-op installation for stateless components. Generated code in an external application module must not require `package`, `internal` or test-only access to runtime slots. Macro tests must include compiling an external consumer with private state properties, not just comparing expanded source text.

State getters read the installed cell and register a dependency when a component body is being evaluated. Setters are nonmutating at the view-value level, update the cell synchronously on the main actor, and notify the update driver. Event closures capturing a view value retain access to the installed cell rather than a detached copy of its value.

For `Equatable` values, unchanged assignments produce no invalidation. Other value types invalidate on assignment. Mutating a property inside an arbitrary reference object stored in `State` does not automatically become observable; its owner must replace the value or use a later observable-model adapter.

Reject state mutation during body evaluation, measurement or painting with a clear development diagnostic. Bodies describe UI; side effects belong in event handlers or explicit application work. A stale binding/callback from an unmounted generation cannot mutate a replacement component or remount it. After unmount, writes are ignored with a diagnostic in development; retained reads may see the last detached value but create no subscription.

State storage is local to a mounted root. Independent hosts/test roots do not share cells, registries, dependency scopes or scheduling flags.

## Bindings and event handling

`Binding<Value>` exposes a getter and setter, a constant/read-only form and key-path projection for value models. `$draft` returns a binding to the installed cell. Each read participates in the currently evaluating body's dependency scope, including when a parent-owned binding is read by a child component.

Add overloads alongside existing controlled-value factories:

```swift
TextField(id: "filter", text: $filter)
TextEditor(id: "draft", text: $draft)
List(id: "files", rows: files, selection: $selectedFile)
Table(id: "commits", columns: columns, rows: rows, selection: $selectedCommit)
Tabs(id: "section", tabs: sections, selection: $section)
```

Support the underlying string and optional-selection types deliberately, including adapters for controls whose action payload is a nonoptional string. Keep `value:` and ordinary `selection:` overloads intact. Bindings do not create a second editor/list/table implementation.

Binding and closure modifiers produce behavior descriptors, registered under the owning component and control identity when the body resolves. The existing routers still emit `UIAction`; the presentation source routes recognized actions to the active binding or closure. A recognized bound action is consumed once, without also sending the same mutation through a legacy `handle(_:)`. Unclaimed actions reach the legacy application/root handler.

Use a single closure registration per event such as `.onSubmit { ... }`, with fresh captures installed whenever its owning component body is reevaluated. Unchanged bodies keep their registrations. Component-input changes must reevaluate that child even if its local state did not change; do not skip this because its type/key stayed the same. Replace generation-scoped registrations atomically with the resolved subtree and discard removed ones.

For custom bindings, invoke the setter once and allow it to validate/normalize the value. Read back authoritative state on the next resolution. Equality suppression belongs at the actual storage boundary, so it cannot bypass a custom setter with useful behavior.

Command behavior remains Enter to submit, Shift+Enter to add a newline, and paste as data. Modal shortcut scoping, disabled controls and menu availability continue to use the existing routers.

## Scheduled updates and input ordering

Add a main-actor update driver with a dirty-component set, a pending-flush flag and a monotonic revision counter. A state mutation updates its value immediately and marks affected work; it does not synchronously render. The first mutation schedules one flush. Additional mutations before that flush add to the same work set. Inject scheduling and clocks for deterministic tests; avoid a task per mutation and an unconditional animation timer.

Integrate with terminal I/O using a dedicated application-update wakeup descriptor, separate from the existing process-signal pipe. A background state write can wake an otherwise idle host. Extend Linux polling and the Darwin C wait helper to observe it. Coalesce wake writes, drain them before resolving work, and join/cancel pending reads before closing descriptors during teardown. Do not rely on the current approximately 30 ms escape polling interval as the new update scheduler.

The host loop becomes:

1. Apply each event's state/binding/closure effects synchronously.
2. Before dispatching another event that requires current values, focus targets, callbacks or geometry, flush pending component resolution and prepare geometry as needed.
3. At the frame boundary, resolve remaining dirty work, reconcile and lay out the result, then paint one frame.
4. Write an immutable frame snapshot. Mutations arriving during awaited output remain pending for the next transaction.

Separate **interaction consistency flushes** from **terminal frame commits**. A batched read containing typing followed by Enter or a click on newly revealed content must observe the updated state. It may require more than one component evaluation before one output frame. Do not promise one body evaluation for an arbitrary input packet or suppress those correctness barriers just to improve a counter.

Introduce a transaction operation for grouping synchronous programmatic mutations. Transactions defer scheduled resolution/output, not the underlying writes; reads in the same handler see the latest values. A transaction is not database rollback or an animation mechanism. Errors leave already applied state observable, close the transaction scope and schedule the corresponding update.

Legacy `host.invalidate()` remains available and means conservative root invalidation. The existing action-driven adapter retains its rebuild behavior. A new component presentation does not automatically invalidate the whole root for every successfully handled binding action.

## Selective component rebuilding

First implement scheduling with conservative root reevaluation, then refine it using recorded dependencies:

- Track state-slot reads while each body runs. Replace that component's dependency set after a successful evaluation; unsubscribe from properties no longer read.
- A changed slot dirties only subscribed component bodies. Merely owning state is not enough to force an owner-body rebuild when only a child reads the binding.
- Evaluate dirty ancestors before descendants. Ancestor reconciliation may remove a dirty descendant, refresh its inputs or make a separate queued evaluation unnecessary.
- For newly supplied child values, reevaluate that child conservatively. Equality-based input skipping can be added explicitly later; callbacks and closures are not safely compared by reflection.
- Cache each mounted component's resolved output. Child-only state changes update that child's output and the ancestor output path without calling unaffected ancestor bodies.
- Maintain separate body and resolved-subtree revisions. A child changing can advance an ancestor's subtree revision without reevaluating that ancestor's body.
- Preserve a transparent component boundary in the resolved element tree. `LayoutNode.update` skips descendant reconciliation only when boundary identity and subtree revision are unchanged. It uses identity-aware matching for keyed component peers.
- Propagate size changes through ancestor measurement caches. A growing composer can reduce its sibling's available viewport even though the sibling's body never runs.

Selective body evaluation is distinct from selective layout, painting and terminal output. The existing full visible-grid comparison remains valid. Repaint enclosing scroll views/overlays when clipping or compositing requires it. Preserve the current built-in viewport repaint path; do not initially promise widget-only painting for every state update.

## Delivery phases

| Phase | Work | Acceptance criteria |
| --- | --- | --- |
| 1. Component boundaries | Core descriptor/boundary support, `TerminalView`, `Component`, keyed repetition, mounted records, presentation-source adapter and transparent renderer traversal. | Stateless structs compose with both layout APIs; reorder keeps keyed instances; focus, mouse, modal discovery and reveal work through boundaries. |
| 2. Persistent state | Typed store, declaration keys, generation/lifecycle rules, `State` wrapper and macro-generated installation. Initially use conservative dirty-root resolution. | Recreated structs retain state; initializer runs once per mount; same-named state is isolated between instances; removal/replacement releases state; stale writes cannot affect a replacement. |
| 3. Bindings and callbacks | Bound-control overloads, projected bindings, scoped control identity, action/closure registry and legacy fallback. | Editors and selections work without action-switch boilerplate; custom setters run once; callbacks use current inputs; two identical local control IDs do not collide; command submission/paste behavior is preserved. |
| 4. Scheduled transactions | Shared update driver, injected scheduler, wakeup descriptor, explicit input consistency barriers and lifecycle cleanup. | Multiple state writes in a handler/burst schedule one frame; background writes wake an idle host; batched typing is correct; stale geometry and lost updates during output are excluded; legacy tests retain their contracts. |
| 5. Dependency-driven rebuilds | State-read tracking, dirty-subtree traversal, output revisions and retained boundary reconciliation. | A child-only edit does not rerun unrelated sibling or parent bodies; changed child inputs still rebuild; dynamic subscriptions are replaced; size changes correctly relayout siblings; retained scrolling stays efficient. |
| 6. Demo migration and public API completion | Convert LayoutDemo into independent header/navigation, topic inspector and command components; share state through bindings; document mixed migration and scoped focus. | The demo's central action switch no longer handles bound text/selection changes; keyboard/pointer workflows and state survival pass end-to-end; public examples use real compiled APIs. |

Sequence: 1 → 2 → 3 → 4 → 5 → 6. Each phase should produce a runnable slice; migrate a small command component during phases 2–3, then finish the complete demo in phase 6. Phases organize delivery, not approval gates.

## Validation and instrumentation

Add `TerminalUIComponentRuntimeTests`, `TerminalUIComponentsTests` and macro expansion/compiler tests. Retain the existing compatibility, layout, host and PTY suites. New assertions should measure behavior rather than repeat internal algorithms.

| Area | Required evidence |
| --- | --- |
| Identity | Keyed reorder, insertion/deletion, duplicate-key diagnostics, conditional same-type branches, type/key replacement and independent roots. |
| State lifetime | Struct recreation, initializer count, conditional unmount/remount, hidden-but-mounted state, declaration separation, stale callback/binding behavior and released storage. |
| Bindings | Typing/deletion, multiline paste, Enter/Shift+Enter, list/table/tab selection, projected value mutations, setter normalization, read-only bindings and legacy fallback without double delivery. |
| Scheduling | Deterministic explicit flushes, grouped writes, no-op assignments, idle background changes, mutation during awaited output, cancellation/teardown and transactions exiting through errors. |
| Input consistency | `a` then `b` yields `ab`; state-changing activation then Tab/Enter/mouse targets the current tree; an opened modal blocks workspace shortcuts immediately; resize cancels stale presses. |
| Incrementality | Body-call counts for child-only state, shared-state subscribers, newly supplied inputs, removed subscriptions, ancestor/descendant dirty overlap and untouched sibling reconciliation. |
| Layout/rendering | Wrapped editor growth, ancestor measurement invalidation, scroll anchoring, dialog composition, wide characters, clipped pointer targets and retained versus full-frame equality. |
| End-to-end | LayoutDemo shortcuts, command search, two independent editors, draft survival through parent refresh/reorder, Enter submission, Shift+Enter newlines, idle state updates and terminal restoration. |

Expose internal/test counters for state writes, scheduled flushes, body evaluations, component reconciliations, measurements, paints and frame writes. Keep these separate so fewer terminal writes cannot disguise excessive body rebuilding. Add representative benchmarks with reported measurements rather than machine-dependent timing thresholds.

Use a component-subtree reference renderer to compare incremental results with full reevaluation across sequences of edits, navigation, resize and keyed reorder. Verify the legacy facade still builds from ordinary imports without requiring component macros.

## Completion and follow-up scope

The migration is complete when all four requested capabilities work in the migrated LayoutDemo, mixed old/new applications are supported, dependency-based body counts demonstrate selective rebuilding, and the existing interaction/rendering/terminal tests remain green.

General animations, persistence across application restarts, full SwiftUI compatibility, automatic observation of arbitrary reference models, a broad environment system and a general effect/task framework are outside this migration. They can build on the mounted identity and scheduling contracts later. Application-owned asynchronous work can already update installed bindings/state on the main actor; its completions obey the generation and wakeup rules above.
