/// The lower-level, action-driven application contract remains available without components.
@MainActor
public protocol TerminalApplication: AnyObject {
    func view() -> Element
    func handle(_ action: UIAction)
}

/// Services supplied by a terminal host, or a terminal-independent harness.
@MainActor
public struct PresentationServices {
    public var requestUpdate: () -> Void
    public var focus: (String, Element) -> Bool
    public var reveal: (String) -> Void

    public init(
        requestUpdate: @escaping () -> Void = {},
        focus: @escaping (String, Element) -> Bool = { _, _ in false },
        reveal: @escaping (String) -> Void = { _ in },
    ) {
        self.requestUpdate = requestUpdate
        self.focus = focus
        self.reveal = reveal
    }
}

/// Supplies fully resolved elements. A host never evaluates component bodies itself.
@MainActor
public protocol TerminalPresentationSource: AnyObject {
    var hasPendingUpdates: Bool { get }
    var revision: UInt64 { get }
    func connect(_ services: PresentationServices)
    func resolve(invalidateRoot: Bool) -> Element
    func handle(_ action: UIAction)
}

/// An explicit, generation-scoped control address obtained from a mounted component root.
public struct ScopedFocusTarget: Hashable, Sendable {
    package let engineID: String
    package init(engineID: String) {
        self.engineID = engineID
    }
}
