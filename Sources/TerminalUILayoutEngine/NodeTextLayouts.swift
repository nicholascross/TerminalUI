import TerminalUICore
import TerminalUIText

/// Bridges retained layout nodes to a terminal-independent text cache.
package struct NodeTextLayouts {
    let cache: TextLayoutCache
    package let tracksSource: Bool
    package var layoutCount: Int {
        cache.layoutCount
    }

    package init(cache: TextLayoutCache, tracksSource: Bool = false) {
        self.cache = cache
        self.tracksSource = tracksSource
    }

    package func layout(_ text: String, width: Int, retaining node: LayoutNode) -> WrappedText {
        let entry = cache.entry(text, width: node.element.wrapsParagraph ? width : nil,
                                tracksSource: tracksSource && node.element.isTextSelectable,
                                reusing: node.textLayout)
        node.textLayout = entry
        guard case let .plain(layout) = entry.layout else { preconditionFailure("Expected plain text layout") }
        return layout
    }

    package func layout(_ spans: [TextSpan], width: Int, retaining node: LayoutNode) -> WrappedStyledText {
        let entry = cache.entry(spans, width: node.element.wrapsParagraph ? width : nil,
                                tracksSource: tracksSource && node.element.isTextSelectable,
                                reusing: node.textLayout)
        node.textLayout = entry
        guard case let .styled(layout) = entry.layout else { preconditionFailure("Expected styled text layout") }
        return layout
    }
}
