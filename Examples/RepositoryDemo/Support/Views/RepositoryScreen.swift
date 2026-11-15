import TerminalUI

/// Hosts repository state scoped to the directory. Constructing the screen does not query Git.
@TerminalComponent
public struct RepositoryScreen: TerminalView {
    private let directory: String

    public init(directory: String) {
        self.directory = directory
    }

    public var body: some TerminalView {
        RepositoryLoader(directory: directory).id(directory)
    }
}

@TerminalComponent
private struct RepositoryLoader: TerminalView {
    let directory: String
    @State private var result: Result<RepositoryViewModel, Error>

    init(directory: String) {
        self.directory = directory
        // State evaluates this initial value once, when the screen mounts.
        _result = State(wrappedValue: Self.load(directory: directory))
    }

    var body: some TerminalView {
        switch result {
        case .success:
            RepositoryBrowser(model: loadedModel)
        case .failure(let error):
            RepositoryLoadFailure(
                directory: directory, error: error,
                retry: { result = Self.load(directory: directory) })
        }
    }

    /// The browser shares the successful model stored in result; it never owns a copy.
    private var loadedModel: Binding<RepositoryViewModel> {
        Binding(
            get: {
                guard case .success(let model) = result else {
                    preconditionFailure("The repository browser requires a successfully loaded model")
                }
                return model
            },
            set: { result = .success($0) })
    }

    private static func load(directory: String) -> Result<RepositoryViewModel, Error> {
        Result { try RepositoryViewModel(repository: GitRepository(directory: directory)) }
    }
}
