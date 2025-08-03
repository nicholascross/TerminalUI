import Foundation

/// A simple spinning indicator widget driven by global `.tick` events.
/// Use for indefinite progress or animation.
public final class SpinnerWidget: Widget {
    /// Optional title displayed above the spinner (rendered in border by UIEventLoop).
    public var title: String?
    public var isUserInteractive: Bool = false
    public var isDisabled: Bool = false
    public var isBorderHidden: Bool = true

    /// Sequence of characters to cycle through on each tick.
    private let frames: [Character]
    /// Current frame index.
    private var frameIndex = 0

    /// Create a spinner widget.
    /// - Parameters:
    ///   - frames: The characters to cycle through (default: "|", "/", "-", "\\").
    ///   - title: Optional title displayed in widget border.
    public init(frames: [Character] = ["|", "/", "-", "\\"], title: String? = nil) {
        self.frames = frames
        self.title = title
    }

    public func render(into renderer: EventLoopRenderer, region: Region) {
        // Clear region
        for r in 0..<region.height {
            for c in 0..<region.width {
                renderer.setCell(row: region.top + r,
                                 col: region.left + c,
                                 char: " ",
                                 style: [])
            }
        }
        // Draw current frame centered
        let ch = frames[frameIndex]
        let col = region.left + region.width / 2
        let row = region.top + region.height / 2
        renderer.setCell(row: row, col: col, char: ch, style: [])
    }

    @discardableResult
    public func handle(event: InputEvent) -> Bool {
        guard case .tick(_) = event else { return false }
        frameIndex = (frameIndex + 1) % frames.count
        return true
    }
}
