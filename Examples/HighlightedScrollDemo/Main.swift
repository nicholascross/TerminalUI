import Foundation
import TerminalUIChroma
import TerminalUIEngine

@MainActor
private final class SourceViewer: TerminalApplication {
    let host: TerminalHost
    let title: String
    let viewport: Element
    private var tick: Int?

    init(host: TerminalHost, title: String, viewport: Element, live: Bool) {
        self.host = host
        self.title = title
        self.viewport = viewport
        tick = live ? 0 : nil
    }

    func view() -> Element {
        let heading = tick.map { "Tick \($0) · \(title)" } ?? title
        return .column([
            .text(heading).role(.heading),
            viewport,
            .statusBar("Wheel / ↑↓ scroll · Drag to copy · Home/End jump · Ctrl-C quit"),
        ])
    }

    func advanceClock() {
        guard let tick else { return }
        self.tick = tick + 1
        host.invalidate()
    }

    func handle(_ action: UIAction) {
        if case .unhandledKey(.controlC) = action { host.stop() }
    }
}

@main
struct HighlightedScrollDemo {
    @MainActor static func main() async throws {
        let arguments = CommandLine.arguments.dropFirst()
        let live = arguments.contains("--live")
        let file = arguments.first { $0 != "--benchmark" && $0 != "--live" }
        let url = URL(fileURLWithPath: file ?? "Sources/TerminalUILayoutEngine/LayoutMeasurer.swift")
        let contents = try String(contentsOf: url, encoding: .utf8)
        let bundledCopies = live ? 10 : 20
        let source = String(repeating: contents, count: file == nil ? bundledCopies : 1)
        let rows = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).count
        let lineCount = rows - (source.last?.isNewline == true ? 1 : 0)
        let spans = try SyntaxHighlighter().spans(source, language: "swift")
        let paragraph = Element.paragraph(spans).textSelection()
        let document: Element
        if live {
            let numbers = (0 ..< rows).lazy.map { String($0 + 1) }.joined(separator: "\n")
            let gutter = Element.paragraph(numbers).wrapping(false).role(.secondary)
                .alignment(.trailing).width(.fixed(String(rows).count))
            document = .row(spacing: 2, [gutter, paragraph.wrapping(false).width(.fill())])
        } else {
            document = paragraph
        }
        let theme = Theme.nord()
        let host = TerminalHost(configuration: .init(mouseEnabled: true, copyOnSelect: true), theme: theme)
        let viewer = SourceViewer(
            host: host, title: "\(url.lastPathComponent) · \(lineCount.formatted()) lines",
            viewport: .scrollView(id: "source", content: document).height(.fill()), live: live,
        )
        if arguments.contains("--benchmark") {
            benchmark(viewer.view(), theme: theme)
        } else {
            let clock = Task {
                guard live else { return }
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(1)) } catch { return }
                    viewer.advanceClock()
                }
            }
            defer { clock.cancel() }
            try await host.run(viewer)
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
