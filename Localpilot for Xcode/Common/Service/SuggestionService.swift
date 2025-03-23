import Foundation

public protocol SuggestionServiceType: SuggestionServiceProvider {}

typealias WorkspaceInfo = XcodeAppInstanceInspector.WorkspaceInfo

public class SuggestionService: SuggestionServiceType {
//    let service = Service()

    public init() {}

    public func notifyAccepted(_ suggestion: CodeSuggestion, workspaceInfo: WorkspaceProjectInfo) async {}

    public func notifyRejected(_ suggestions: [CodeSuggestion], workspaceInfo: WorkspaceProjectInfo) async {}

    public func cancelRequest(workspaceInfo: WorkspaceProjectInfo) async {
//        await service.cancelRequest()
    }

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo workspace: WorkspaceProjectInfo
    ) async throws -> [CodeSuggestion] {
//        try await service.getSuggestions(request, workspace: workspace)
        [CodeSuggestion(id: UUID().uuidString, text: "HOHOHOHO!", position: request.cursorPosition, range: CursorRange(start: request.cursorPosition, end: request.cursorPosition))]
    }
}

