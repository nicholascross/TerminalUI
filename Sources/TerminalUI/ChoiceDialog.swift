import TerminalUICore

/// An option displayed in a choice dialog. IDs must be unique within the dialog.
public struct DialogOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    public static let acknowledge = Self(id: "acknowledge", title: "OK")
}

extension TerminalView {
    /// Presents a compact modal above this view. Choosing an option clears `isPresented` before calling `onChoose`.
    /// Omit the options for a single OK button. Escape leaves the dialog open until a choice is made.
    public func choiceDialog(
        id: String, title: String, message: String = "", isPresented: Binding<Bool>,
        options: [DialogOption] = [], initialOption: DialogOption.ID? = nil,
        onChoose: @escaping @MainActor (DialogOption) -> Void = { _ in },
    ) -> some TerminalView {
        precondition(Set(options.map(\.id)).count == options.count, "Choice dialog option IDs must be unique")
        return ChoiceDialogPresentation(
            content: self, id: id, title: title, message: message, isPresented: isPresented,
            options: options.isEmpty ? [.acknowledge] : options, initialOption: initialOption,
            onChoose: onChoose)
    }
}

private struct ChoiceDialogPresentation<Content: TerminalView>: TerminalView {
    let content: Content
    let id: String
    let title: String
    let message: String
    let isPresented: Binding<Bool>
    let options: [DialogOption]
    let initialOption: DialogOption.ID?
    let onChoose: @MainActor (DialogOption) -> Void

    var body: some TerminalView {
        content.overlay {
            if isPresented.wrappedValue {
                Dialog(id: id, title: title, compact: true) {
                    ChoiceDialogBody {
                        if !message.isEmpty {
                            ScrollView(id: "\(id):message") { Paragraph(message) }
                        }
                        if options.count == 1, let option = options.first {
                            button(option, preferred: true)
                        } else {
                            ScrollView(id: "\(id):options") {
                                Column {
                                    let preferred = options.first { $0.id == initialOption } ?? options.first
                                    for option in options {
                                        button(option, preferred: option.id == preferred?.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .onDismiss {}
            }
        }
    }

    private func button(_ option: DialogOption, preferred: Bool) -> ModifiedView<Button> {
        let buttonID = "\(id):option:\(option.id)"
        return ModifiedView(content: Button(option.title, id: buttonID)) { element in
            var element = element
            var activate = ElementBehavior(.activate, id: buttonID) { _ in
                isPresented.wrappedValue = false
                onChoose(option)
            }
            activate.requiresRefresh = !isPresented.tracksState
            element.behaviors.append(activate)
            element.prefersInitialFocus = preferred
            return element
        }
    }
}

private struct ChoiceDialogBody<Content: TerminalView>: PrimitiveView {
    typealias Body = Never
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    func lower(path: [CompositionAddress]) -> [Element] {
        var element = Element.layout(ChoiceDialogLayout(), children: lowerView(content, path: path))
        element.compositionPath = path
        return [element]
    }
}

private struct ChoiceDialogLayout: ElementLayout {
    func sizeThatFits(_ proposal: LayoutProposal, subviews: [LayoutSubview]) -> WidgetSize {
        let idealWidth = subviews.map { $0.sizeThatFits(.init()).width }.max() ?? 0
        let width = min(idealWidth, proposal.width ?? idealWidth)
        let idealHeight = subviews.reduce(max(0, subviews.count - 1)) { $0 + $1.sizeThatFits(.init(width: width)).height }
        return WidgetSize(width: width, height: min(idealHeight, proposal.height ?? idealHeight))
    }

    func placeSubviews(in size: WidgetSize, subviews: [LayoutSubview]) -> [LayoutPlacement] {
        guard subviews.count == 2 else { return [.init(index: 0, x: 0, y: 0, size: size)] }
        let message = subviews[0].sizeThatFits(.init(width: size.width)).height
        let choices = subviews[1].sizeThatFits(.init(width: size.width)).height
        let gap = size.height >= 3 ? 1 : 0
        let available = size.height - gap
        // Reserve room for both scroll regions on small screens, with at least one choice visible.
        let visibleChoices = min(choices, max(1, available - min(message, available / 2)))
        let visibleMessage = min(message, max(0, available - visibleChoices))
        return [
            .init(index: 0, x: 0, y: 0, size: .init(width: size.width, height: visibleMessage)),
            .init(index: 1, x: 0, y: visibleMessage + gap, size: .init(width: size.width, height: visibleChoices)),
        ]
    }
}
