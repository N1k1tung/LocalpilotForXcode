import Foundation

public final class SuggestionServiceWorkspacePlugin: WorkspacePlugin {
    public typealias SuggestionServiceFactory = () -> any SuggestionServiceProvider
    let suggestionServiceFactory: SuggestionServiceFactory

    let suggestionFeatureUsabilityObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    private var _suggestionService: SuggestionServiceProvider?

    public var suggestionService: SuggestionServiceProvider? {
        // Check if the workspace is disabled.
        let isSuggestionDisabledGlobally = UserDefaults.shared
            .value(for: \.disableSuggestionFeatureGlobally)
        if isSuggestionDisabledGlobally {
            let enabledList = UserDefaults.shared.value(for: \.suggestionFeatureEnabledProjectList)
            if !enabledList.contains(where: { path in projectRootURL.path.hasPrefix(path) }) {
                // If it's disable, remove the service
                _suggestionService = nil
                return nil
            }
        }

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

        suggestionFeatureUsabilityObserver.onChange = { [weak self] in
            guard let self else { return }
            _ = self.suggestionService
        }

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

