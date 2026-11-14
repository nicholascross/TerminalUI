This change introduces a shared core and six implementation targets around it. It is intended for review as a module ownership migration, not a binary-compatible release.

The existing SwiftPM products are retained. Consumers continue to depend on the `TerminalUI` product and write `import TerminalUI`. The facade declares explicit aliases, so qualified source references such as `TerminalUI.Element`, `TerminalUI.UIEngine` and `TerminalUI.CustomWidget` continue to compile. Existing factories, default arguments and protocol requirements remain available.

The nominal declarations now belong to these modules:

| New owner | Existing public types | Public declarations, including members |
| --- | --- | --- |
| `TerminalUICore` | 33 types: Element and supporting models, Canvas/CellGrid/Cell, styling, events/actions, display width, custom-widget contracts and contexts. | 357 |
| `TerminalUIInput` | `InputDecoder` | 7 |
| `TerminalUIRendering` | `UIEngine`, `FrameEncoder` | 18 |
| `TerminalUIRuntime` | `TerminalApplication`, `TerminalConfiguration`, `TerminalError`, `TerminalHost` | 30 |
| Total | 40 existing types, also named by facade aliases. | 412 |

The exact alias list is in [Exports.swift](../Sources/TerminalUI/Exports.swift). The [architecture note](Architecture.md) describes the dependency graph and package-only contracts.

The ownership change affects mangled symbols, nominal module identity, reflection strings and generated documentation ownership. For example, `String(reflecting: TerminalUI.Element.self)` now identifies `TerminalUICore.Element`. Existing compiled clients must be rebuilt. Aliases preserve source names; they do not restore the old binary symbols. Code or tooling that relies on reflected module names needs review.

Validation compares the original library's 412 public declarations with the aggregate declarations in Core, Input, Rendering and Runtime. Paths, declaration spelling, symbol kinds and availability are preserved; the owning modules and their symbol identities intentionally change. The facade adds 40 aliases rather than duplicating implementations. The syntax-highlighting adapter remains a separate product.

The compatibility test target imports only `TerminalUI` and exercises qualified names, custom-widget conformance, application conformance, input decoding, rendering, frame encoding and host APIs. A separate consumer typecheck outside the Swift package checks ordinary imports and tab/menu factories; a negative typecheck verifies that the package-only element representation remains inaccessible.

Existing behavioural tests remain in place. Focused input, interaction-state and runtime-policy tests now compile in their own targets against the modules they exercise. Retained rendering tests continue to compare targeted frames with full renders and check that scrolling does not add view calls or measurements. PTY checks exercise the running demo and terminal restoration on Linux.

Migration validation passed all 180 tests across 33 suites and the Linux PTY integration checks. The core also typechecked in isolation without implementation-module search paths.

A subsequent composition refactor delegates engine behaviour to `FrameRenderer`, `KeyboardRouter` and `PointerRouter`, with authoritative focus and widget-state owners. It preserves the public declarations and owning modules established by this migration. Interaction now depends on Layout for its expiring geometry contract; Rendering has no routing backreferences.
