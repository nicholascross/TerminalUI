# Layout demo

Run `swift run LayoutDemo` for the interactive demo, or `swift run LayoutDemo --preview` for a plain-text snapshot. Pass `--no-mouse` to preserve the terminal's normal text selection.

```text
LayoutDemo/
├── App/                 # LayoutDemo executable: entry point, theme and configuration
└── Support/             # LayoutDemoSupport module, imported by the app and tests
    ├── Models/          # Shared pane destinations
    ├── ViewModels/      # Shared presentation state and commands
    └── Views/           # Root screen and individual view components
```

`LayoutScreen` composes the demo's views and owns `LayoutViewModel`. Use the framework's `MenuBar` and `Menu` directly; extracted views group meaningful layout or behavior rather than forward a control's arguments.

Both menus take `Pane.allCases` directly and focus the activated pane by default. `Pane` conforms to `MenuItemDefinition` for its title; shortcut numbers and the bar's Alt/Control aliases are automatic. A separate adjacent button opens Commands with `.keyboardShortcut(.controlP)`.

| Owner | State and responsibilities |
| --- | --- |
| `LayoutScreen` / `LayoutViewModel` | Status and command-menu presentation. The current pane is read reactively from the application context. |
| Application context / focus runtime | Actual focused destination, exposed through `focusedValue(of:)`; views register typed targets. |
| `WorkspaceView` | Selected topic, shared through a binding with `TopicsView` and passed as a read-only value to `InspectorView`. |
| `CommandPane` | Draft text. Submitting reports the draft to the screen and clears the local editor. |
| `Menu` | Search text and highlighted result. Removing the conditional menu discards these; reopening starts a new search. |
| `MenuBar` | Keyboard highlight, separate from the current pane supplied by the screen. |

Each pane control registers its typed destination with `.focusTarget(Pane.command)` (or the corresponding pane). Menus use `application.focus(pane)` internally. The screen reads `application.focusedValue(of: Pane.self)` for active-item display and hints, and uses `.onFocusChange(of: Pane.self)` for status messages. There is no navigation wrapper, view-path mapping or mirrored focus state. View IDs still supply subtree identity and reveal addressing. All child views mount automatically; no component wrapper is needed.

The command menu demonstrates a conditional modal overlay. `.onActivate` dismisses it before default focus moves to the selected pane. Escape and its Return button use the same `.onDismiss` callback. Pane shortcuts, menu activation and pointer input preserve the workspace selection and command draft. Status follows actual pane focus changes, including Tab and pointer input.

The Topics list requests `.initialFocus()`, so startup focus is in the workspace. Contextual hints explain topic selection, inspector scrolling or command input above a persistent shortcut line. Both hint lines fit a 60-column terminal. The Quit button uses an activation callback without an explicit ID; only controls that need focus lookup have application-defined control IDs.

The SwiftPM targets use separate source directories so the support module can be tested without the executable entry point. Demo tests live in `Tests/LayoutDemoTests` and use the public `ApplicationHarness` without importing the engine or runtime. Run `swift test --filter LayoutNavigationTests`; after building, run `python3 Scripts/test-terminalui-layout-pty.py` from the repository root for terminal interaction checks.
