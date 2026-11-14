import Foundation
import LayoutDemoSupport
import TerminalUIComponents

@main
struct LayoutDemo {
    @MainActor
    static func main() async throws {
        let app = LayoutApplication(mouseEnabled: !CommandLine.arguments.contains("--no-mouse"))
        if CommandLine.arguments.contains("--preview") {
            for line in UIEngine(theme: .dusk()).render(app.presentation.resolve(), width: 80, height: 24) {
                print(line)
            }
        } else {
            try await app.host.run(app.presentation)
        }
    }
}
