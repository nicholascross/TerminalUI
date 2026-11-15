import Foundation
import TerminalUI

struct RepositoryInspector: TerminalView {
    let title: String
    let output: String
    let revision: Int
    let showsCommit: Bool
    let hasNewer: Bool
    let hasOlder: Bool
    let newer: () -> Void
    let older: () -> Void

    var body: some TerminalView {
        Panel("Inspect · \(title)") {
            Column {
                if showsCommit {
                    Row(spacing: 1) {
                        Button("Newer").enabled(hasNewer).onActivate { newer() }
                        Button("Older").enabled(hasOlder).onActivate { older() }
                    }
                }
                ScrollView(id: "output") {
                    Column {
                        for line in output.components(separatedBy: "\n") {
                            Text(line).role(role(for: line))
                        }
                    }
                }
                .focusTarget(RepositoryPane.inspector)
                .id(revision)
                .height(.fill())
            }
        }
    }

    private func role(for line: String) -> TextRole {
        if line.hasPrefix("+") { return .success }
        if line.hasPrefix("-") { return .error }
        if line.hasPrefix("@@") { return .info }
        return .normal
    }
}
