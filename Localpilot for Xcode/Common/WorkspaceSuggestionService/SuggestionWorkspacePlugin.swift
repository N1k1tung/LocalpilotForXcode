import Foundation

public final class SuggestionServiceWorkspacePlugin: WorkspacePlugin {
    public typealias SuggestionServiceFactory = () -> any SuggestionServiceProvider
    let suggestionServiceFactory: SuggestionServiceFactory

    private var _suggestionService: SuggestionServiceProvider?

    public var suggestionService: SuggestionServiceProvider? {
        if _suggestionService == nil {
            _suggestionService = suggestionServiceFactory()
        }
        return _suggestionService
    }

    public init(
        workspace: Workspace,
        suggestionProviderFactory: @escaping SuggestionServiceFactory
    ) {
        suggestionServiceFactory = suggestionProviderFactory
        super.init(workspace: workspace)

        _ = self.suggestionService
    }

    func notifyAccepted(_ suggestion: CodeSuggestion) async {
        await suggestionService?.notifyAccepted(
            suggestion,
            workspaceInfo: .init(workspaceURL: workspaceURL, projectURL: projectRootURL)
        )
    }

    func notifyRejected(_ suggestions: [CodeSuggestion]) async {
        await suggestionService?.notifyRejected(
            suggestions,
            workspaceInfo: .init(workspaceURL: workspaceURL, projectURL: projectRootURL)
        )
    }
}

