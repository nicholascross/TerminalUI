import Foundation

/// A text input widget capturing line input.
public class TextInputWidget: Widget {
    /// Optional title displayed over the top border of the input.
    public var title: String?
    /// This widget handles user input and can be focused.
    public var isUserInteractive: Bool { return true }
    /// Prompt shown before input.
    public let prompt: String
    /// Current input buffer.
    public private(set) var buffer: String = ""

    public init(prompt: String = "> ", title: String? = nil) {
        self.prompt = prompt
        self.title = title
    }

    /// Handle character and control events; returns completed line on Enter.
    @discardableResult
    public func handle(event: InputEvent) -> String? {
        switch event {
        case .char(let c):
            buffer.append(c)
            return nil
        case .backspace:
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return nil
        case .enter:
            // Insert a newline for multi-line editing rather than submitting immediately
            buffer.append("\n")
            return nil
        case .submit:
            // Submit the entire buffer (e.g. on Ctrl-D)
            let text = buffer
            buffer = ""
            return text
        default:
            return nil
        }
    }

    /// Render the input prompt and buffer into the given region.
    public func render(into renderer: Renderer, region: Region) {
        // Split buffer into lines (preserve empty final line)
        let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Clear full region
        for y in 0..<region.height {
            for x in 0..<region.width {
                renderer.setCell(row: region.top + y, col: region.left + x, char: " ")
            }
        }
        // Draw each line (prefix prompt on first line)
        for (i, line) in lines.enumerated() {
            guard i < region.height else { break }
            let cleaned = line.replacingTabs()
            let text = (i == 0 ? prompt + cleaned : cleaned)
            for (j, ch) in text.prefix(region.width).enumerated() {
                renderer.setCell(row: region.top + i, col: region.left + j, char: ch)
            }
        }
    }
}

// MARK: - Widget conformance
extension TextInputWidget {
    public func handle(event: InputEvent) -> Bool {
        if let _ = self.handle(event: event) {
            return true
        }
        return false
    }
}
