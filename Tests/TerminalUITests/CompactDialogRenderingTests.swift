import TerminalUIEngine
import TerminalUIRendering
import Testing

struct CompactDialogRenderingTests {
    @Test func `compact dialog dims wide workspace glyphs while focus changes resend only dialog content`() throws {
        let workspace = Element.text("界 workspace")
        var dialog = Element.dialog(
            id: "notice", title: "Notice",
            content: .column([
                .button("First", id: "first"), .button("Second", id: "second"),
            ]))
        dialog.isCompactDialog = true
        let root = workspace.overlay(dialog)
        let engine = UIEngine(theme: .light)
        let first = engine.renderGrid(root, width: 40, height: 12)
        let wide = try #require(first[0, 0])
        #expect(wide.grapheme == "界")
        #expect(wide.style.foreground == .rgb(141, 145, 156))
        #expect(first[1, 0]?.style == wide.style)
        #expect(first.lines[0].hasPrefix("界 workspace"))
        #expect(first.lines[4].contains("Notice"))

        var output = FrameEncoder(capability: .trueColor)
        _ = output.prepare(first)
        output.commit()
        _ = engine.handle(.tab, in: root)
        let next = engine.renderGrid(root, width: 40, height: 12)
        let changed = output.prepare(next)
        #expect(changed.contains("Second"))
        #expect(!changed.contains("workspace"))
        #expect(next[0, 0] == wide)
    }

    @Test func `terminal default backdrops only change style when faint is enabled`() {
        var dialog = Element.dialog(id: "notice", title: "Notice", content: .button("OK", id: "ok"))
        dialog.isCompactDialog = true
        let root = Element.text("Workspace").overlay(dialog)
        let enabled = UIEngine(textSelectionEnabled: false, backdropFaintEnabled: true)
        let disabled = UIEngine(textSelectionEnabled: false, backdropFaintEnabled: false)
        #expect(enabled.renderGrid(root, width: 40, height: 12)[0, 0]?.style.dim == true)
        #expect(disabled.renderGrid(root, width: 40, height: 12)[0, 0]?.style.dim == false)
    }
}
