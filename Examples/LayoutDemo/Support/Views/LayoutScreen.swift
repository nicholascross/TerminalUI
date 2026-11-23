import Foundation
import TerminalUI

@TerminalComponent
public struct LayoutScreen: TerminalView {
    private enum NotificationExample: String, CaseIterable {
        case acknowledgement, info, success, warning, error

        var option: DialogOption {
            .init(id: rawValue, title: self == .acknowledgement ? "Acknowledgement" : "\(rawValue.capitalized) banner")
        }

        var bannerStyle: Banner.Style? {
            switch self {
            case .acknowledgement: nil
            case .info: .info
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
    }

    private struct BannerPreview {
        let style: Banner.Style
        let id = UUID().uuidString
    }

    @State private var model = LayoutViewModel()
    @State private var previousTheme: Theme?
    @State private var showingNotifications = false
    @State private var showingAcknowledgement = false
    @State private var banner: BannerPreview?
    @ApplicationContext private var application

    public init() {}

    private var focusedPane: Pane? { application.focusedValue(of: Pane.self) }

    public var body: some TerminalView {
        Column(spacing: 1) {
            HeaderView(
                themeTitle: previousTheme == nil ? "Light theme" : "Restore theme",
                changeTheme: toggleTheme,
                quit: { application.stop() }
            )
            Row(spacing: 1) {
                MenuBar(id: "navigation", items: Pane.allCases, activeItem: focusedPane)
                    .id("navigation")
                Button("Commands")
                    .onActivate { model.openCommands() }
                    .keyboardShortcut(.controlP)
                Button("Notifications")
                    .onActivate { showingNotifications = true }
                    .keyboardShortcut(.altCharacter("n"))
            }
            WorkspaceView(topics: model.topics, submit: { model.submit($0) })
                .id("workspace")
            Column {
                if let banner {
                    Banner("This sample clears after three seconds.", style: banner.style, timeout: .seconds(3), id: banner.id)
                }
                StatusBar(model.status)
            }
            Column {
                Text(model.contextualHints(for: focusedPane)).role(.secondary)
                Text("Alt+1–3 panes · Ctrl-P menu · Alt+T theme · Ctrl-C quit").role(.secondary)
            }
        }
        .overlay {
            if model.commandsOpen {
                Menu(
                    id: "commands", title: "Layout commands",
                    items: Pane.allCases, initialSelection: focusedPane,
                    itemTitle: { "Focus \($0.title)" }
                )
                .onActivate { model.dismissCommands() }
                .onDismiss { model.dismissCommands() }
            }
        }
        .choiceDialog(
            id: "notification-examples", title: "Notifications", message: "Choose a banner style or try an acknowledgement dialog.",
            isPresented: $showingNotifications, options: NotificationExample.allCases.map(\.option), onChoose: previewNotification,
        )
        .choiceDialog(
            id: "acknowledgement", title: "Acknowledgement", message: "The workspace stays visible behind this dialog. Choose OK to close it.",
            isPresented: $showingAcknowledgement,
        )
        .onFocusChange(of: Pane.self) { pane in
            if let pane { model.didFocus(pane) }
        }
        .onAction(handle)
    }

    private func previewNotification(_ option: DialogOption) {
        guard let example = NotificationExample(rawValue: option.id) else { return }
        if let style = example.bannerStyle {
            banner = BannerPreview(style: style)
        } else {
            showingAcknowledgement = true
        }
    }

    private func toggleTheme() {
        if let previousTheme {
            application.theme = previousTheme
            self.previousTheme = nil
        } else {
            previousTheme = application.theme
            application.theme = .light
        }
    }

    private func handle(_ action: UIAction) -> Bool {
        guard case .unhandledKey(.controlC) = action else { return false }
        application.stop()
        return true
    }
}
