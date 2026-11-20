# Highlighted scroll demo

Run from the repository root to browse twenty copies of `LayoutMeasurer.swift` as one highlighted document. The sample includes source lines up to 150 columns wide that wrap in a typical terminal.

```sh
swift run HighlightedScrollDemo
```

Scroll with the mouse wheel, arrow keys, or Page Up and Page Down. Home and End jump between the first and last pages. Drag across the source to copy it on release. During a drag, hold the pointer at the top or bottom edge or use the wheel to select beyond the visible lines. Press Ctrl-C to quit.

Use live mode to review a fixed line-number gutter alongside a selectable, clipped paragraph.

```sh
swift run HighlightedScrollDemo --live
```

In a narrow terminal, drag across several code rows and hold through a tick in the heading. The highlight stays visible. Release to copy the code, including clipped text on intervening lines. Dragging to a clipped row's right edge also copies its hidden tail. The line numbers are outside the selection.

Run the same scrolling workload headlessly at 88 columns by 30 rows to measure median input handling and repaint time.

```sh
swift run HighlightedScrollDemo --benchmark
```

The benchmark measures scrolling after the source has been highlighted and first displayed. It renders in memory and excludes terminal output.

Pass a Swift file path to display or benchmark that file.

```sh
swift run HighlightedScrollDemo /path/to/sample.swift
```
