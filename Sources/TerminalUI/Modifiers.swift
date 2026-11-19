import TerminalUICore

public struct ModifiedView<Content: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let content: Content
    let transform: @MainActor (Element) -> Element
    let deferToBody: Bool
    init(content: Content, deferToBody: Bool = false, transform: @escaping @MainActor (Element) -> Element) {
        self.content = content
        self.deferToBody = deferToBody
        self.transform = transform
    }
    package func lower(path: [CompositionAddress]) -> [Element] {
        lowerView(content, path: path).map { deferToBody ? $0.applyingDeferredModifier(transform) : transform($0) }
    }
}

extension TerminalView {
    public func width(_ value: LayoutSize) -> ModifiedView<Self> { ModifiedView(content: self) { $0.width(value) } }
    public func height(_ value: LayoutSize) -> ModifiedView<Self> { ModifiedView(content: self) { $0.height(value) } }
    public func layoutSizing(width: LayoutPreference = .automatic, height: LayoutPreference = .automatic) -> ModifiedView<Self> {
        ModifiedView(content: self) { $0.layoutSizing(width: width, height: height) }
    }
    public func padding(_ value: Insets) -> ModifiedView<Self> { ModifiedView(content: self) { $0.padding(value) } }
    public func alignment(_ value: Alignment) -> ModifiedView<Self> { ModifiedView(content: self) { $0.alignment(value) } }
    public func role(_ value: TextRole) -> ModifiedView<Self> { ModifiedView(content: self) { $0.role(value) } }
    public func style(_ value: StyleOverride) -> ModifiedView<Self> { ModifiedView(content: self) { $0.style(value) } }
    public func foreground(_ value: TextStyle.Color) -> ModifiedView<Self> { style(.init(foreground: value)) }
    public func background(_ value: TextStyle.Color) -> ModifiedView<Self> { style(.init(background: value)) }
    public func bold(_ value: Bool = true) -> ModifiedView<Self> { style(.init(bold: value)) }
    public func dim(_ value: Bool = true) -> ModifiedView<Self> { style(.init(dim: value)) }
    public func italic(_ value: Bool = true) -> ModifiedView<Self> { style(.init(italic: value)) }
    public func underline(_ value: Bool = true) -> ModifiedView<Self> { style(.init(underline: value)) }
    public func visible(_ value: Bool) -> ModifiedView<Self> { ModifiedView(content: self) { $0.visible(value) } }
    public func enabled(_ value: Bool) -> ModifiedView<Self> { ModifiedView(content: self) { $0.enabled(value) } }
    /// Allows mouse text selection on this Text or Paragraph when the host enables copy on select.
    public func textSelection(_ enabled: Bool = true) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { $0.textSelection(enabled) }
    }
    public func onKey(_ key: KeyEvent, activate id: String) -> ModifiedView<Self> {
        ModifiedView(content: self, deferToBody: true) { $0.onKey(key, activate: id) }
    }
    public func onSubmit(_ id: String) -> ModifiedView<Self> { ModifiedView(content: self, deferToBody: true) { $0.onSubmit(id) } }
    /// Identifies a subtree for focus paths and reveal. Changing the ID resets its state.
    public func id<ID: Hashable>(_ id: ID) -> IdentityView<Self, ID> { IdentityView(content: self, id: id) }
    public func scope<ID: Hashable>(_ id: ID) -> ScopeView<Self, ID> { ScopeView(content: self, id: id) }
    public func overlay<Overlay: TerminalView>(_ overlay: Overlay?) -> OverlayView<Self, Overlay> { OverlayView(content: self, overlay: overlay) }
    public func overlay<Overlay: TerminalView>(@ViewBuilder content: () -> Overlay) -> OverlayView<Self, Overlay> {
        OverlayView(content: self, overlay: content())
    }
}

public struct OverlayView<Content: TerminalView, Overlay: TerminalView>: PrimitiveView {
    public typealias Body = Never
    let content: Content
    let overlay: Overlay?
    package func lower(path: [CompositionAddress]) -> [Element] {
        // Keep both slots even when the optional overlay is absent.
        var base = rootElement(lowerView(content, path: path + [.slot(0)]))
        if let overlay {
            let elements = lowerView(overlay, path: path + [.slot(1)])
            if !elements.isEmpty { base = base.overlay(rootElement(elements)) }
        }
        base.compositionPath = path
        return [base]
    }
}

private struct IdentityContent<Content: TerminalView>: TerminalView {
    let content: Content
    var body: Content { return content }
}

public struct IdentityView<Content: TerminalView, ID: Hashable>: PrimitiveView {
    public typealias Body = Never
    let content: Content
    let id: ID
    package func lower(path: [CompositionAddress]) -> [Element] {
        let key = AnyHashable(ViewID(id))
        var element = Element.component(ViewDescriptor(value: IdentityContent(content: content)))
        element.compositionPath = path + [.key(key)]
        element.viewID = key
        return [element]
    }
}

/// Names a lookup scope without making the name an identity reset boundary.
public struct ScopeView<Content: TerminalView, ID: Hashable>: PrimitiveView {
    public typealias Body = Never
    let content: Content
    let id: ID
    package func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.component(ViewDescriptor(value: IdentityContent(content: content)))
        element.compositionPath = path
        element.scopeID = AnyHashable(ViewID(id))
        return [element]
    }
}
