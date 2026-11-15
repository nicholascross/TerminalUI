# TerminalUI

Build declarative terminal applications in Swift with `import TerminalUI`. Views compose with opaque bodies, mounted state and bindings; the framework owns terminal hosting, input and rendering. Swift 6.3 is required. The package retains its macOS 13 and iOS 15 deployment targets; interactive terminal integration is exercised on Linux.

```swift
import TerminalUI

@main
@TerminalApplication
struct NotesApp {
    var root: some TerminalView { Workspace() }
    var theme: Theme { .dusk() }
}

@TerminalComponent
struct Workspace: TerminalView {
    @State private var draft = ""
    @ApplicationContext private var application

    var body: some TerminalView {
        Column(spacing: 1) {
            Text("Notes").role(.heading)
            Panel("Command") {
                TextEditor(id: "draft", text: $draft)
                    .onSubmit { draft = "" }
            }.height(.fit(maximum: 8))
            Button("Quit").onActivate { application.stop() }
        }
    }
}
```

Views mount automatically, and state is installed before body evaluation. Conditional branches have separate lifetimes, fixed sibling slots remain stable, and `ForEach(items, id: \.id)` preserves item state across reorder. `.id(value)` establishes subtree identity; changing it resets the subtree. View IDs and `ForEach` item IDs also support focus paths and reveal. Local control IDs remain separate from view IDs.

Built-in themes include `.terminalNative`, `.dark`, `.light`, `.dusk()`, `.tokyoNight()`, `.dracula()`, `.nord()`, `.ayuLight()` and `.everforest()`. Light and Ayu Light paint their own light backgrounds; Everforest uses a dark green-grey palette. The named presets include backgrounds, control states and syntax colours, with automatic colour capability detection. Applications select their theme when creating `TerminalApp`.

Run the examples and terminal-independent previews:

```sh
swift run LayoutDemo
swift run LayoutDemo --preview
swift run RepositoryDemo --repo /path/to/repository
swift run RepositoryDemo --preview
swift run EngineDemo
swift run EngineDemo --preview
```

The examples have distinct roles:

| Example | Purpose |
| --- | --- |
| [LayoutDemo](Examples/LayoutDemo/README.md) | Layout, state, bindings and typed pane navigation. |
| [RepositoryDemo](Examples/RepositoryDemo/README.md) | A read-only Git browser structured as a component application. |
| [EngineDemo](Examples/EngineDemo/README.md) | A small raw-engine application using `Element` and `TerminalHost`. |

Public API consumers and interaction probes live under `Tests/Fixtures`; they are validation fixtures rather than runnable package examples.

Use `TerminalApp(root:)` to run or preview a screen directly. `ApplicationHarness(root:)` supports previews, keyboard/mouse input, transactions, invalidation, focus and reveal without acquiring a terminal.

| Product | Use |
| --- | --- |
| `TerminalUI` | Views, controls, containers, modifiers, macros, state, bindings, application services and testing. |
| `TerminalUIArgumentParser` | Optional typed application arguments, generated initialization, shared terminal flags and help. |
| `TerminalUIEngine` | Raw elements, legacy applications, hosting, rendering, decoding, drawing and custom widgets. |
| `TerminalUIBridge` | Explicit engine/declarative interoperability in both directions. |
| `TerminalUIChroma` | Optional syntax highlighting returning shared semantic text spans. |

Neither public entry point re-exports implementation modules. Engine-only consumers do not depend on the high-level module or macro tooling. Chroma spans work with `Paragraph(spans)` and engine `Element.paragraph(spans)`.

See [components and mounted state](Documentation/Components.md), [application arguments](Documentation/Arguments.md), [negotiated layout](Documentation/Negotiated-Layout.md), [architecture](Documentation/Architecture.md), and the [engine guide](Documentation/Engine.md). This is a breaking API migration: follow the [migration guide](Documentation/High-Level-API-Migration.md). The [implementation plan](Documentation/Specs/TerminalUI/High-Level-API-Architecture-Plan.md) records the boundary, identity contract and validation.

```sh
swift test -j 4
bash Scripts/test-terminalui-components-consumer.sh
python3 Scripts/test-terminalui-components-pty.py
python3 Scripts/test-terminalui-layout-pty.py
python3 Scripts/test-terminalui-layout-pty.py --no-mouse
python3 Scripts/test-terminalui-pty.py
python3 Scripts/test-terminalui-engine-pty.py
```
