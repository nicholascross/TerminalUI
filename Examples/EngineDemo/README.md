# Engine demo

A single-file application using raw `Element` values and an explicit `TerminalHost`. For the declarative layout DSL, start with the [layout demo](../LayoutDemo/README.md).

```sh
swift run EngineDemo
```

Tab moves between controls, arrows select topics and scroll details, and Ctrl-C quits. Mouse input is enabled; use `--no-mouse` to preserve normal terminal text selection.

[EngineDemo.swift](EngineDemo.swift) shows how to compose a topic list, scrolling detail pane, text field and Quit button. Its action handler applies text and selection changes to application values, while the host retains focus, caret position and scrolling through stable control IDs.

See [engine and custom controls](../../Documentation/Engine.md) for the API and [architecture and development](../../Documentation/Architecture.md#repository-checks) for validation commands.
