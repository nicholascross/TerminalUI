# Engine demo

A small, single-file example for consumers of `TerminalUIEngine`. Most application authors should start with LayoutDemo or RepositoryDemo and `import TerminalUI`.

```sh
swift run EngineDemo
swift run EngineDemo --preview
swift run EngineDemo --no-mouse
```

`EngineApplication` composes raw `Element` values for a topic list, a scrolling detail pane, an in-memory text field and a Quit button. `handle(_:)` applies selection and text actions to application values. `TerminalHost` owns terminal acquisition, rendering and input, retaining focus, caret and scrolling through stable control IDs.

Tab moves between controls, arrows select topics and scroll details, and Ctrl-C quits. Mouse input is enabled by default; `--no-mouse` preserves normal terminal selection. `--preview` prints a snapshot without a controlling TTY.

After building, run `python3 Scripts/test-terminalui-engine-pty.py` for the example and private engine interaction checks. Regression-only controls are kept in `Tests/Fixtures/EngineInteractionProbe`, outside this example.
