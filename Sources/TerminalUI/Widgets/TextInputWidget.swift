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
        case .char(let character):
            buffer.append(character)
            return nil
        case .backspace:
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return nil
        case .enter:
            let text = buffer
            buffer = ""
            return text
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
        for rowOffset in 0..<region.height {
            for colOffset in 0..<region.width {
                renderer.setCell(row: region.top + rowOffset, col: region.left + colOffset, char: " ")
            }
        }
        // Draw each line (prefix prompt on first line)
        for (lineIndex, line) in lines.enumerated() {
            guard lineIndex < region.height else { break }
            let cleaned = line.replacingTabs()
            let text = (lineIndex == 0 ? prompt + cleaned : cleaned)
            for (charIndex, char) in text.prefix(region.width).enumerated() {
                renderer.setCell(row: region.top + lineIndex, col: region.left + charIndex, char: char)
            }
        }
    }
}

// MARK: - Widget conformance
extension TextInputWidget {
    public func handle(event: InputEvent) -> Bool {
        if self.handle(event: event) != nil {
            return true
        }
        return false
    }
}
