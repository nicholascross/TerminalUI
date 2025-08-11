import Foundation
import Testing
@testable import TerminalUI

@Suite("TextInputWidget")
struct TextInputWidgetTests {
    /// Feed a sequence of input events to a fresh TextInputWidget.
    @MainActor
    private func feed(_ events: [InputEvent]) -> TextInputWidget {
        let widget = TextInputWidget(prompt: "", title: nil)
        for event in events {
            // Use the String-returning handler to update internal lines
            _ = (widget.handle as (InputEvent) -> String?)(event)
        }
        return widget
    }

    @Test
    @MainActor
    func multilinePasteSplitsLines() {
        let pasteText = "first line\nsecond line\nthird"
        var events: [InputEvent] = [.pasteStart]
        for char in pasteText {
            events.append(.char(char))
        }
        events.append(.pasteEnd)
        let widget = feed(events)
        let result = widget.buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let expected = pasteText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(result == expected)
    }
}
