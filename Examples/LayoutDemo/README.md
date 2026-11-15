# Layout demo

Run `swift run LayoutDemo` for the interactive demo, or `swift run LayoutDemo --preview` for a plain-text snapshot. Pass `--no-mouse` to preserve the terminal's normal text selection.

```text
LayoutDemo/
├── App/                 # LayoutDemo executable: entry point, theme and configuration
└── Support/             # LayoutDemoSupport module, imported by the app and tests
    ├── Models/          # Shared pane destinations
    ├── Navigation/      # Scoped focus and application navigation
    ├── ViewModels/      # Shared presentation state and commands
    └── Views/           # Root screen and individual view components
```

`LayoutScreen` composes the demo's views and owns `LayoutViewModel`. Components keep local state or receive shared bindings as needed. Each view has its own Swift file.

The SwiftPM targets use separate source directories so the support module can be tested without the executable entry point. Demo tests live in `Tests/LayoutDemoTests` at the repository root. Run `swift test --filter LayoutNavigationTests`; after building, run `python3 Scripts/test-terminalui-layout-pty.py` from the repository root for terminal interaction checks.
