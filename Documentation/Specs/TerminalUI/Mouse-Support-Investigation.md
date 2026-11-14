# TerminalUI mouse support investigation

Status: historical investigation that guided the mouse implementation. See [TerminalUI](../../../README.md) for the implemented API and behavior. The proposals and validation plan below record the original investigation; real-terminal compatibility remains to be verified.

The requested interactions fit in TerminalUI: menu and button clicks, wheel scrolling under the pointer, and click-to-focus for fields and panels. Applications should continue to own values and actions. TerminalUI should own mouse decoding, geometry, routing, focus and viewport offsets.

## Current implementation

| Boundary | Existing behavior | Required addition |
| --- | --- | --- |
| `InputDecoder` | Incremental bytes-to-`KeyEvent` parsing; unknown CSI sequences are discarded | An ordered stream of keyboard and mouse events |
| `TerminalSession` / `TerminalConfiguration` | Raw TTY setup and teardown, keyboard and paste modes | Configurable mouse reporting and matching cleanup |
| `TerminalHost` | Dispatches key batches; rebuilds the view before the next event as needed | Mouse dispatch against current geometry, including within a batch |
| `UIEngine` | Stable control IDs, modal focus trapping, caret and viewport state | Hit testing, pointer press capture, click focus, wheel routing |
| `UIEngine+Render` | Computes geometry while painting, including scrolling and clipping | Retain visible interaction regions and coordinate transforms |
| `CustomWidget` | Keyboard response only | A defaulted mouse response with local coordinates and assigned size |

These sources are under `Sources/TerminalUI`. `Layout/LayoutNode.swift` caches measurements and tree structure, but does not retain allocated control rectangles. Geometry cannot be recovered from `focusedBounds`, which is only a temporary vertical extent used for focus reveal.

`MenuBarWidget` and `TabsWidget` are custom widgets. `Element.menu` composes a dialog, text field, list and button. Panels and dialogs draw borders around children; there is no independent window type or window focus state.

## Proposed interaction contract

| Target | Primary click | Wheel |
| --- | --- | --- |
| Button | Focus on press; activate once on release over the same button | Route to enclosing scroll area |
| Menu bar item | Focus the bar; select the pressed item; activate the available item on matching release | Route to enclosing scroll area |
| Searchable menu result | Focus/select the pressed row; activate that available row on matching release | Scroll results without changing selection or focus |
| Ordinary list/table row | Focus and select; retain Enter submission behavior | Scroll viewport without changing selection or focus |
| Text field/editor | Focus; place caret at the clicked grapheme boundary and clear selection | Scroll multiline viewport; single-line fields defer to an enclosing scroll area |
| Scroll view | Focus its own region when clicking unclaimed background | Scroll the region under the pointer without moving keyboard focus |
| Panel title/border/background | Keep focus if already inside; otherwise focus its first enabled descendant; direct child hits take precedence | Route by the scroll region under the pointer |

“Window focus” here means panel-content focus, matching the existing library. A panel without focusable descendants does nothing. Dialogs continue to trap focus and mouse input; clicks outside an active dialog do not reach underlying controls or dismiss it automatically.

Hidden, clipped and disabled controls cannot receive focus or activation. Disabled rows remain selectable for inspection, as they are with the keyboard, but do not activate. Only visible row cells are hit targets; row spacing and table headers do not select rows. Text clicks must account for wrapping, horizontal clipping, scroll offsets, wide graphemes, empty values and clicks after the end of a line.

For nested scrolling, target the deepest enabled scrollable region under the pointer. If it is at its limit, try its enclosing scroll region. Use a fixed, bounded vertical step initially. Drag selection, continuous hover highlighting, double-click semantics, horizontal scrolling and movable/resizable windows can remain outside this implementation.

## Terminal reporting

Use normal mouse tracking (`?1000h`) with SGR encoding (`?1006h`). SGR reports button, column and row as `CSI < b ; x ; y M` for presses and a lowercase `m` for releases. Wheel reports contain coordinates and have no release event, so scrolling under the pointer does not require continuous motion reporting (`1003`). Normalize terminal coordinates from one-based cells to zero-based cells. These facilities are described in the [XTerm control-sequence reference](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Mouse-Tracking).

Propose an opt-in `TerminalConfiguration.mouseEnabled`, initially defaulting to `false` to preserve existing terminal selection behavior. Setup and teardown must track whether reporting was requested, including partial setup failure. Keyboard navigation remains available. Emulator and multiplexer behavior requires real-terminal checks; this investigation establishes protocol feasibility, not a verified compatibility matrix.

## Implementation approach

1. **Add mouse events without changing the keyboard contract.** Introduce `TerminalEvent` (`key` / `mouse`) and `MouseEvent` with phase/button or wheel direction, cell position and modifiers. Add `InputDecoder.feedEvents`; keep `feed` as a keyboard-only compatibility wrapper over the same parser. Keep `KeyEvent` and existing application action handling intact. Add an explicit engine mouse entry point and a default `.unhandled` mouse response on `CustomWidget`, so existing conformers compile unchanged.

2. **Retain geometry from the drawing path.** Record final screen-space bounds, ancestor clips, paint order, semantic targets and scroll ancestors. Record list row extents while drawing, since wrapping and row spacing make arithmetic based only on row index incorrect. Custom widgets receive local coordinates relative to their content canvas, with clipping enforced by the engine. Menu bars should share item-layout calculations between drawing and hit testing, including focus markers, Unicode widths and overflow.

   Scroll painting uses temporary canvases with content-local coordinates, and can paint twice after focus reveal changes the offset. Transform hit regions through the final offset and retain only the final pass. Overlay backgrounds block underlying targets even where there is no interactive child. Retained viewport repainting must replace regions for the repainted subtree while preserving unaffected regions; a fresh full geometry traversal for every wheel event would undermine retained scrolling.

3. **Make geometry current before pointer dispatch.** `TerminalHost` currently rebuilds a changed view before the next event in a batch, but painting happens afterward. A new tree has no allocated rectangles yet. Recompute geometry before routing a subsequent mouse event after an action, resize or viewport change, and after focus changes that affect menu widths. Reuse the existing paint path initially if necessary, with output coalesced until the batch finishes. This also handles several wheel events followed by a click in one read. Never apply old rectangles to a rebuilt tree. Define direct engine mouse handling to require geometry from the current rendered tree, or return a harmless no-op when unavailable.

4. **Separate pointer scrolling from automatic reveal.** Scroll views currently reveal focused children on every paint. Editors similarly reveal their caret, and lists/tables reveal the selected row. A wheel offset alone would be undone immediately. Track when reveal is requested: focus/caret/selection navigation and explicit `keepVisible` should reveal, while manual wheel scrolling should allow the focus/caret/selection to remain offscreen. Preserve clamping and follow-end behavior. `pendingScrollID` must identify the hovered scroll target rather than `focusedID`; extend retained repaint routing for list, table and editor viewports as well as `.scroll` nodes.

5. **Route clicks to semantic targets.** Capture the pressed control/item ID; activate only on a matching primary release over the current visible target. Cancel capture if the target disappears, becomes disabled, or a modal/resize invalidates it. A release without a press cannot activate. Application selection actions may rebuild the tree between press and release, so capture cannot depend on node identity or an old rectangle.

6. **Give menus the clicked item's action.** `Element.menu` currently attaches `.onSubmit(selected.id)` to the whole list. Synthesizing Enter after clicking a different row could activate the previous selection. Add explicit optional per-row activation metadata, defaulting to absent for ordinary lists; populate it with each menu item's ID. Enter and mouse activation can then use the same row-owned action and availability rule. Keep the search field's current-selection submission behavior. Press emits selection change, and release emits activation, preserving the existing single-action result contract.

This keeps terminal protocol work at the runtime/input boundary, hit testing and focus in the engine, and item-specific geometry in the widgets that draw it. Panel focusing can use existing descendant IDs without introducing a window manager or persistent panel state.

## Validation required for implementation

- Decoder tests across every byte split: press/release, wheel, modifiers, large coordinates, interleaved keys, bracketed paste, invalid/overflowing coordinates, incomplete and oversized sequences. Consume or discard legacy mouse packets as whole packets if encountered: the current generic unknown-CSI path would discard `CSI M` but leave its legacy payload to be decoded as keys.
- Engine tests: complete focus/action outcomes; one activation per click; mismatched releases; disabled and removed targets; modal blocking and restoration; padding, alignment, narrow screens, clipping and overlay occlusion; nested scrolled coordinates; panel-background fallback; wide and wrapped text caret placement.
- Scroll tests: wheel affects the hovered viewport while keyboard focus remains elsewhere; selection/caret does not change; automatic reveal does not undo manual scrolling; subsequent keyboard navigation reveals correctly; nested boundary fallback, clamping, resize and follow-end resume work.
- Menu tests: clicking a nonselected result activates that result, including selection rebuilds between press/release; unavailable rows can be inspected without activation; search and filtered/empty results; clipped menu bar labels and shifted focus markers.
- Host tests: action-then-click, wheel-then-click, resize-then-click and modal-opening batches use current geometry. Retained wheel repaint avoids additional application `view()` calls for unchanged content and preserves unrelated output.
- Extend `Scripts/test-terminalui-pty.py` for mode setup/cleanup and injected clicks/wheel reports. Exercise opt-out, ordinary exit and termination cleanup. A PTY validates bytes and lifecycle, but cannot establish actual emulator mouse behavior.
- Run `swift build`, full `swift test`, and `swiftlint lint` through the repository's validation specialists after code changes. Check actual click/wheel behavior on macOS Terminal, Foot and tmux, including terminal text selection with mouse reporting enabled.

Recommended sequence: decoder/session support, geometry and host dispatch, buttons/fields/panel focus, then wheel/reveal behavior and menus/custom widgets. Ship the feature after the full interaction path and cleanup have coverage. Update `Documentation/TerminalUI.md` and the original design's deferred-mouse statements when implementation lands.
