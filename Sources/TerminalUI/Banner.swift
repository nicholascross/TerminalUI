import TerminalUICore

/// An in-layout notification. Banners leave focus in the current control when they appear.
public struct Banner: PrimitiveView {
    public typealias Body = Never

    public enum Style: Hashable, Sendable {
        case info, success, warning, error

        fileprivate var label: String {
            switch self {
            case .info: "Info"
            case .success: "Success"
            case .warning: "Warning"
            case .error: "Error"
            }
        }

        fileprivate var role: TextRole {
            switch self {
            case .info: .info
            case .success: .success
            case .warning: .warning
            case .error: .error
            }
        }
    }

    public struct Action {
        public let title: String
        fileprivate let perform: @MainActor () -> Void

        public init(_ title: String, perform: @escaping @MainActor () -> Void) {
            self.title = title
            self.perform = perform
        }
    }

    private struct Identity: Hashable {
        let id: String?
        let message: String
        let style: Style
        let timeout: Duration?
    }

    private let identity: Identity
    private let action: Action?

    /// A timeout starts when the banner mounts. Pass a new `id` to show the same message again.
    /// With no timeout the banner remains visible until the app removes it.
    public init(_ message: String, style: Style = .info, timeout: Duration? = nil, id: String? = nil, action: Action? = nil) {
        identity = Identity(id: id, message: message, style: style, timeout: timeout)
        self.action = action
    }

    package func lower(path: [CompositionAddress]) -> [Element] {
        let view = BannerContent(message: identity.message, style: identity.style, timeout: identity.timeout, action: action)
        var element = Element.component(ViewDescriptor(value: view))
        element.compositionPath = path + [.key(AnyHashable(identity))]
        return [element]
    }
}

private struct BannerContent: TerminalView {
    let message: String
    let style: Banner.Style
    let timeout: Duration?
    let action: Banner.Action?

    @State private var expired = false

    mutating func _installState(_ installation: StateInstallation) {
        _expired._install(in: installation, key: "expired")
        guard let timeout else { return }
        let expired = $expired
        installation.context.startTask(key: "expiration") {
            do { try await Task.sleep(for: timeout) } catch { return }
            if !Task.isCancelled { expired.wrappedValue = true }
        }
    }

    var body: some TerminalView {
        Column {
            Paragraph("\(style.label) · \(message)").role(style.role)
            if let action {
                Button(action.title, id: "action").onActivate(action.perform)
            }
        }
        .visible(!expired)
    }
}
