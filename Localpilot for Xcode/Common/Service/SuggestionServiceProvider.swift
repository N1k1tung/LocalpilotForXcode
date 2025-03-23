import AppKit
import Foundation

public struct SuggestionRequest {
    public var fileURL: URL
    public var relativePath: String
    public var content: String
    public var originalContent: String
    public var lines: [String]
    public var cursorPosition: CursorPosition
    public var cursorOffset: Int
    public var tabSize: Int
    public var indentSize: Int
    public var usesTabsForIndentation: Bool
    public var relevantCodeSnippets: [RelevantCodeSnippet]

    public init(
        fileURL: URL,
        relativePath: String,
        content: String,
        originalContent: String,
        lines: [String],
        cursorPosition: CursorPosition,
        cursorOffset: Int,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        relevantCodeSnippets: [RelevantCodeSnippet]
    ) {
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.content = content
        self.originalContent = content
        self.lines = lines
        self.cursorPosition = cursorPosition
        self.cursorOffset = cursorOffset
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
        self.relevantCodeSnippets = relevantCodeSnippets
    }
}

public struct RelevantCodeSnippet: Codable {
    public var content: String
    public var priority: Int
    public var filePath: String

    public init(content: String, priority: Int, filePath: String) {
        self.content = content
        self.priority = priority
        self.filePath = filePath
    }
}

public protocol SuggestionServiceProvider {
    func getSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: WorkspaceProjectInfo
    ) async throws -> [CodeSuggestion]
    func notifyAccepted(
        _ suggestion: CodeSuggestion,
        workspaceInfo: WorkspaceProjectInfo
    ) async
    func notifyRejected(
        _ suggestions: [CodeSuggestion],
        workspaceInfo: WorkspaceProjectInfo
    ) async
    func cancelRequest(workspaceInfo: WorkspaceProjectInfo) async
}

public struct WorkspaceProjectInfo: Codable, Identifiable {
    /// An id.
    public var id: String { workspaceURL.path }
    /// URL to a workspace or project file.
    public var workspaceURL: URL
    /// URL of the project root path.
    public var projectURL: URL

    public init(workspaceURL: URL, projectURL: URL) {
        self.workspaceURL = workspaceURL
        self.projectURL = projectURL
    }

    init() {
        workspaceURL = .init(fileURLWithPath: "/")
        projectURL = .init(fileURLWithPath: "/")
    }
}
