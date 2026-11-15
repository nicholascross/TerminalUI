import Foundation
import TerminalUI

@TerminalComponent
struct RepositoryLoadFailure: TerminalView {
    let directory: String
    let error: Error
    let retry: () -> Void
    @ApplicationContext private var application

    var body: some TerminalView {
        Column(spacing: 1) {
            Text("Repository unavailable").role(.heading)
            Panel("Unable to open repository") {
                Column(spacing: 1) {
                    Paragraph(directory).role(.secondary)
                    Paragraph(error.localizedDescription).role(.error)
                }
            }
            Row(spacing: 1) {
                Button("Retry").onActivate { retry() }.initialFocus()
                Button("Quit").onActivate { application.stop() }
            }
            Spacer()
            StatusBar("Enter retry · Tab focus · Ctrl-C quit")
        }
        .onAction { action in
            guard case .unhandledKey(.controlC) = action else { return false }
            application.stop()
            return true
        }
    }
}
