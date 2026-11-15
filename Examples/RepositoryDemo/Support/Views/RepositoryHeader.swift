import TerminalUI

struct RepositoryHeader: TerminalView {
    let name: String
    let branch: String
    let changedFiles: Int
    let quit: () -> Void

    var body: some TerminalView {
        Row(spacing: 1) {
            Text(name).role(.heading)
            Text("\(branch) · \(changedFiles) changed").role(.secondary).width(.fill())
            Text("READ ONLY").role(.info)
            Button("Quit").onActivate { quit() }
        }
    }
}
