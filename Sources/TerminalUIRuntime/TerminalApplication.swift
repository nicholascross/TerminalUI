public import TerminalUICore

public typealias TerminalApplication = TerminalUICore.TerminalApplication

/// Preserves conservative view rebuilding for action-driven applications.
@MainActor
public final class LegacyApplicationPresentation: TerminalPresentationSource {
    private let application: any TerminalApplication
    private var root: Element?
    public private(set) var revision: UInt64 = 0
    public var hasPendingUpdates: Bool { root == nil }

    public init(_ application: any TerminalApplication) { self.application = application }
    public func connect(_ services: PresentationServices) {}
    public func resolve(invalidateRoot: Bool = false) -> Element {
        if invalidateRoot || root == nil {
            root = application.view()
            revision &+= 1
        }
        return root!
    }
    public func handle(_ action: UIAction) { application.handle(action); root = nil }
}
