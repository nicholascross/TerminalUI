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
            let line = buffer
            buffer = ""
            return line
        default:
            return nil
        }
    }

    /// Render the input prompt and buffer into the given region.
    public func render(into renderer: Renderer, region: Region) {
        let text = prompt + buffer
        // Clear region.
        for x in 0..<region.width {
            renderer.setCell(row: region.top, col: region.left + x, char: " ")
        }
        // Draw prompt and buffer.
        for (j, ch) in text.prefix(region.width).enumerated() {
            renderer.setCell(row: region.top, col: region.left + j, char: ch)
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
