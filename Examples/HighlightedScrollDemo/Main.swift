import Foundation
import TerminalUIChroma
import TerminalUIEngine

@MainActor
private final class SourceViewer: TerminalApplication {
    let host: TerminalHost
    let root: Element

    init(host: TerminalHost, root: Element) {
        self.host = host
        self.root = root
    }

    func view() -> Element { root }

    func handle(_ action: UIAction) {
        if case .unhandledKey(.controlC) = action { host.stop() }
    }
}

@main
struct HighlightedScrollDemo {
    @MainActor static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        let file = arguments.first { $0 != "--benchmark" }
        let url = URL(fileURLWithPath: file ?? "Sources/TerminalUILayoutEngine/LayoutMeasurer.swift")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let source = String(repeating: contents, count: file == nil ? 20 : 1)
        let lineCount = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
            - (source.last?.isNewline == true ? 1 : 0)
        let spans = try SyntaxHighlighter().spans(source, language: "swift")
        let root = Element.column([
            .text("\(url.lastPathComponent) · \(lineCount.formatted()) lines").role(.heading),
            .scrollView(id: "source", content: .paragraph(spans).textSelection()).height(.fill()),
            .statusBar("Wheel / ↑↓ scroll · Drag to copy · Home/End jump · Ctrl-C quit"),
        ])
        let theme = Theme.nord()
        if arguments.contains("--benchmark") {
            benchmark(root, theme: theme)
        } else {
            let host = TerminalHost(configuration: .init(mouseEnabled: true, copyOnSelect: true), theme: theme)
            try await host.run(SourceViewer(host: host, root: root))
        }
    }

    private static func benchmark(_ root: Element, theme: Theme) {
        let engine = UIEngine(theme: theme)
        let clock = ContinuousClock()
        _ = engine.renderGrid(root, width: 88, height: 30)
        let samples = (0 ..< 40).compactMap { index -> Double? in
            let elapsed = clock.measure {
                _ = engine.handleEvent(index.isMultiple(of: 2) ? .down : .pageDown, in: root)
                _ = engine.repaintGrid(width: 88, height: 30)
            }
            guard index >= 5 else { return nil } // Warm up before collecting samples.
            let time = elapsed.components
            return Double(time.seconds) * 1000 + Double(time.attoseconds) / 1e15
        }.sorted()
        print(String(format: "Median scroll input and repaint at 88×30 (%d samples) %.2f ms",
                     samples.count, samples[samples.count / 2]))
    }
}
