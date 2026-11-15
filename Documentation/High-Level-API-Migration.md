# Breaking high-level API migration

Existing compiled clients must rebuild. The old `TerminalUIComponents` and `TerminalUILayout` products have been removed.

| Previous use | Replacement |
| --- | --- |
| `import TerminalUIComponents` | Depend on and `import TerminalUI`. |
| `import TerminalUILayout` for application composition | Depend on and `import TerminalUI`; containers and controls are typed views. |
| Low-level `import TerminalUI` | Depend on and `import TerminalUIEngine`. |
| `var body: Element` | `var body: some TerminalView`, or an explicit concrete view type. |
| `ComponentApplication(root:)` for tests | `ApplicationHarness(root:)`. |
| `runner.host` / `runner.presentation` | `runner.context`, `preview`, `invalidate`, `transaction`, `stop`, or the harness's input operations. |
| Raw elements mixed into view bodies | Opt into `TerminalUIBridge` and use `EngineContent`. |
| A high-level root driven by an engine host | `ViewPresentation(root:)` from `TerminalUIBridge`. |

Stateless views need no macro; mounted `@State` and `@ApplicationContext` still require `@TerminalComponent`. The application entry remains `@main @TerminalApplication` with `root: some TerminalView`.

Containers retain content types and the builder preserves structural identity. Extract helper views instead of manually opening their bodies. Ordinary builder loops are positional. Use `ForEach(items, id: \.id)` when insertion/reorder should retain item state. The builder no longer accepts bare `[Element]` in the high-level API; use typed repetition or the explicit bridge.

Conditional branch changes now reset branch-local state, even when both branches contain the same component type. Optional siblings preserve later fixed slots. Equal item keys are allowed in separate repetition scopes. Use `.scope(value)` and scoped lookup to disambiguate focus/reveal addresses; ambiguous paths fail.

High-level `.id(value)` has **identity and reveal** semantics. Changing it resets all state and handles beneath the modifier. It accepts stable hashable values and preserves their concrete type through lookup. Engine `Element.id(String)` remains **reveal-only**. Control `id:` arguments remain local control addresses. Reveal requests themselves never reset state.

`TerminalUIChroma` returns the same Core-owned semantic spans for either API. It no longer depends on a facade. Engine-only users avoid the high-level module and macro build; bridge users accept those dependencies.

Qualified view type names, reflection and overload resolution may change with nominal ownership. Importing both entry points can require `TerminalUI.Text` or `TerminalUIEngine.Text`. No compatibility re-exports restore the previous boundary.
