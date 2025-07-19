import Foundation

/// A simple list widget displaying select-able items.
public class ListWidget {
    /// Items to display in the list.
    public var items: [String]
    /// Currently selected index.
    public var selectedIndex: Int = 0

    public init(items: [String]) {
        self.items = items
    }

    /// Handle navigation keys; returns true if event consumed.
    @discardableResult
    public func handle(event: InputEvent) -> Bool {
        switch event {
        case .upArrow:
            selectedIndex = max(0, selectedIndex - 1)
            return true
        case .downArrow:
            selectedIndex = min(items.count - 1, selectedIndex + 1)
            return true
        default:
            return false
        }
    }

    /// Render visible lines given a height.
    public func render(height: Int) -> [String] {
        let count = min(height, items.count)
        var lines = [String]()
        for i in 0..<count {
            let prefix = (i == selectedIndex ? "▶ " : "  ")
            lines.append(prefix + items[i])
        }
        // Pad if fewer items than height
        if count < height {
            lines.append(contentsOf: Array(repeating: "", count: height - count))
        }
        return lines
    }
}

/// A text input widget capturing line input.
public class TextInputWidget {
    /// Prompt shown before input.
    public let prompt: String
    /// Current input buffer.
    public private(set) var buffer: String = ""

    public init(prompt: String = "> ") {
        self.prompt = prompt
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

    /// Render the input line at bottom.
    public func render() {
        let text = prompt + buffer
        print(text, terminator: "")
        fflush(stdout)
    }
}
