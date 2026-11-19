import TerminalUI

struct RepositoryHelp: TerminalView {
    let dismiss: () -> Void

    var body: some TerminalView {
        Dialog(id: "help", title: "Read-only Git browser") {
            Column(spacing: 1) {
                Paragraph(
                    "Files shows Git's index and working tree status columns. Select a file for its working diff. Press e in the Files list to open the file in your editor. Staged diff shows index changes. Refresh reloads external changes."
                )
                Paragraph(
                    "Select a branch to inspect its recent history without checking it out. Select a commit for its message, author, dates and patch. Newer and Older step through the latest 50 commits on HEAD."
                )
                Paragraph(
                    "Alt+1–4 focuses a pane. Tab moves between controls. Wheel scrolls under the pointer. Ctrl-P opens repository commands. Escape closes dialogs. This application only runs read-only Git queries."
                )
                Button("Close").onActivate { dismiss() }
            }
        }
        .onDismiss { dismiss() }
    }
}
