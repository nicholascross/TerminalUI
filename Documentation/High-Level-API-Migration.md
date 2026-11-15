# Breaking high-level API migration

Existing compiled clients must rebuild. The old `TerminalUIComponents` and `TerminalUILayout` products have been removed.

| Previous use | Replacement |
| --- | --- |
| `import TerminalUIComponents` | Depend on and `import TerminalUI`. |
| `import TerminalUILayout` for application composition | Depend on and `import TerminalUI`; containers and controls are typed views. |
| Low-level `import TerminalUI` | Depend on and `import TerminalUIEngine`. |
| `var body: Element` | `var body: some TerminalView`, or an explicit concrete view type. |
| `Component(view, key: value)` | `view.id(value)`. Views mount automatically; the ID also supplies focus-path and reveal addressing. |
| `Component(view)` | `view`. |
| `ComponentApplication(root:)` for tests | `ApplicationHarness(root:)`. |
| `MenuAction` arrays or builders | `MenuBar(id:items:activeItem:onActivate:)` or `Menu(id:title:items:initialSelection:onActivate:)` with typed values. Conform to `MenuItemDefinition` or supply `itemTitle:`. |
| Per-item numeric shortcut and Alt/Control bindings | Automatic numbered access. Override `menuShortcut` with `.key(...)` or `.none` where needed. |
| Application-specific focus path/ID wrappers | Register `.focusTarget(destination)` on each control and call `application.focus(destination)`. Observe `.onFocusChange(of: Destination.self)` for typed focus feedback. |
| Mirrored focused destination in `@State` or a view model | Read `application.focusedValue(of: Destination.self)`; the runtime tracks view dependencies. |
| Repeated menu callbacks that only request focus | Omit the activation closure for default typed focus. Use `.onActivate` for surrounding work; provide a callback to replace focus with a custom action. |
| `runner.host` / `runner.presentation` | `runner.context`, `preview`, `invalidate`, `transaction`, `stop`, or the harness's input operations. |
| Raw elements mixed into view bodies | Opt into `TerminalUIBridge` and use `EngineContent`. |
| A high-level root driven by an engine host | `ViewPresentation(root:)` from `TerminalUIBridge`. |

Stateless views need no macro; mounted `@State` and `@ApplicationContext` still require `@TerminalComponent`. The application entry remains `@main @TerminalApplication` with `root: some TerminalView`.

Containers retain content types and the builder preserves structural identity. Extract helper views instead of manually opening their bodies. Ordinary builder loops are positional. Use `ForEach(items, id: \.id)` when insertion/reorder should retain item state. The builder no longer accepts bare `[Element]` in the high-level API; use typed repetition or the explicit bridge.

Conditional branch changes now reset branch-local state, even when both branches contain the same component type. Optional siblings preserve later fixed slots. Equal item IDs are allowed in separate repetition scopes. Use `.scope(value)` and scoped lookup to disambiguate focus/reveal addresses; ambiguous paths fail.

High-level `.id(value)` has **identity, focus-path and reveal** semantics. Changing it resets all state and handles beneath the modifier. It accepts stable hashable values and preserves their concrete value type through lookup, including `AnyHashable` erasure. Engine `Element.id(String)` remains **reveal-only**. Control `id:` arguments remain local control addresses. Reveal requests themselves never reset state.

`focusTarget(path:id:)` follows view IDs and `ForEach` item IDs instead of component keys. Unidentified views are transparent; identified subtrees require a path entry. For example, `Workspace().id("workspace")` containing `Editor().id("editor")` uses `focusTarget(path: ["workspace", "editor"], id: "draft")`. `ForEach` registers each item ID for both focus and reveal, so remove a redundant `.id(item.id)` inside its content unless an additional nested boundary is intended. `.scope(value)` remains available for naming lookup regions without resetting their state.

`TerminalUIChroma` returns the same Core-owned semantic spans for either API. It no longer depends on a facade. Engine-only users avoid the high-level module and macro build; bridge users accept those dependencies.

Qualified view type names, reflection and overload resolution may change with nominal ownership. Importing both entry points can require `TerminalUI.Text` or `TerminalUIEngine.Text`. No compatibility re-exports restore the previous boundary.
