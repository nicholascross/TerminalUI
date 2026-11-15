# Architecture and development

This guide is for contributors and application authors testing their views. For the public layout DSL, start with [layout and sizing](Layout.md) and [views, state and focus](Components.md).

## Package structure

| Product | Purpose |
| --- | --- |
| `TerminalUI` | Declarative views, containers, controls, state, macros and application services. |
| `TerminalUIArgumentParser` | Optional typed arguments and terminal flags. |
| `TerminalUIEngine` | Raw elements, hosting, rendering, input and custom widgets. |
| `TerminalUIBridge` | Explicit integration between declarative views and raw elements. |
| `TerminalUIChroma` | Syntax highlighting as shared semantic text spans. |

The declarative and engine APIs share implementation targets without depending on each other. The bridge depends on both. Public entry points expose curated types rather than re-exporting implementation modules; engine-only consumers do not compile the component macros.

| Implementation target | Responsibility |
| --- | --- |
| `TerminalUICore` | Shared elements, styles, events, layout contracts and opaque handles. |
| `TerminalUIText` | Wrapping, text metrics, editor coordinates and text layout caching. |
| `TerminalUIInput` | Keyboard, paste and mouse decoding. |
| `TerminalUILayoutEngine` | Retained layout nodes, measurement, allocation and geometry. |
| `TerminalUIInteraction` | Keyboard and pointer routing, focus and widget mechanics. |
| `TerminalUIRendering` | Painting, retained frames and terminal encoding. |
| `TerminalUIRuntime` | Hosting, update wakeups and terminal lifecycle. |
| `TerminalUIComponentRuntime` | View identity, state, dependencies and scheduling. |
| `TerminalUIComponentMacros` / `TerminalUIComponentMacroSupport` | Application and component macro expansion. |
| `CTerminalSupport` | Native terminal waiting and signal support. |

[Package.swift](../Package.swift) defines the dependency graph.

## Runtime responsibilities

View composition retains structural identity through conditionals and keyed collections. The component runtime stores local state, records dependencies and schedules affected views. Resolved elements carry revision boundaries so unchanged subtrees can be reused.

`UIEngine` coordinates rendering and interaction. `FrameRenderer` owns the retained tree, clipping, geometry and repaint boundaries. `KeyboardRouter` and `PointerRouter` dispatch input using shared `FocusManager` and `WidgetStateStore` services. Application text and selection remain separate from caret and viewport mechanics.

Pointer routing uses geometry from the current frame. Geometry expires when rendering changes it; a router borrows it for one event. Built-in viewport scrolling can repaint without rebuilding the application view, while focus changes, application actions and resizing rebuild as needed.

`TerminalHost` coordinates the engine, decoder, terminal session and update wakeups. It processes pending state changes before dispatching subsequent input. Terminal session ownership is process-wide because terminal attributes and signal handlers are shared resources.

Shared implementation contracts use Swift `package` access. Renderer and interaction details stay behind the public facades.

## Application testing

Use `ApplicationHarness` to render a view, send input and inspect focus without acquiring a terminal. For example, this checks that editing a bound field updates another view:

```swift
import TerminalUI
import Testing

@TerminalComponent
struct GreetingForm: TerminalView {
    @State private var name = ""

    var body: some TerminalView {
        Column {
            TextField(id: "name", text: $name).initialFocus()
            Text("Hello, \(name)")
        }
    }
}

@Test @MainActor
func greetingUpdates() {
    let app = ApplicationHarness(root: GreetingForm())
    _ = app.preview(width: 40, height: 8)
    app.send(KeyEvent.paste("Ada"))
    let screen = app.preview(width: 40, height: 8).joined(separator: "\n")
    #expect(screen.contains("Hello, Ada"))
}
```

The harness also accepts `TerminalEvent` for mouse input. Its context provides focus and reveal operations; `transaction` batches updates, and `unmount` releases the mounted screen. Metrics are available when diagnosing update behaviour.

## Repository checks

Run commands from the repository root with Swift 6.3. The PTY scripts require Linux and Python 3.

```sh
swift build -j 4
swift test -j 4
```

Check the public API from an external Swift package, including macro expansion and module boundaries:

```sh
bash Scripts/test-terminalui-components-consumer.sh
```

After building, exercise keyboard and mouse input, resizing and terminal restoration:

```sh
python3 Scripts/test-terminalui-components-pty.py
python3 Scripts/test-terminalui-layout-pty.py
python3 Scripts/test-terminalui-layout-pty.py --no-mouse
python3 Scripts/test-terminalui-pty.py
python3 Scripts/test-terminalui-engine-pty.py
```

The repository-browser checks use temporary Git repositories and verify that browsing preserves their working files, index and branch. Private interaction probes live under `Tests/Fixtures`; runnable examples live under `Examples`.

PTY checks cover the host on Linux. Validate Unicode display, modified key reporting and terminal cleanup in the target emulator or multiplexer when changing those behaviours.
