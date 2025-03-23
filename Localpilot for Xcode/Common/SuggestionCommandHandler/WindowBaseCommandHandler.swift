import AppKit
import Foundation
import LanguageServerProtocol
import UserNotifications

struct WindowBaseCommandHandler: SuggestionCommandHandler {
    nonisolated init() {}

    func presentSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return nil
    }

    func presentNextSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        return nil
    }

    func presentPreviousSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        return nil
    }

    func rejectSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await _rejectSuggestion(editor: editor)
            } catch {
                print(error)
            }
        }
        return nil
    }

    @WorkspaceActor
    private func _rejectSuggestion(editor: EditorContent) async throws {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }

        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
    }

    @WorkspaceActor
    func acceptSuggestion(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return nil }
        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

        let injector = SuggestionInjector()
        var lines = editor.lines
        var cursorPosition = editor.cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        if let acceptedSuggestion = workspace.acceptSuggestion(
            forFileAt: fileURL,
            editor: editor,
            suggestionLineLimit: nil
        ) {
            injector.acceptSuggestion(
                intoContentWithoutSuggestion: &lines,
                cursorPosition: &cursorPosition,
                completion: acceptedSuggestion,
                extraInfo: &extraInfo,
                suggestionLineLimit: nil
            )

            return .init(
                content: String(lines.joined(separator: "")),
                newSelection: .cursor(cursorPosition),
                modifications: extraInfo.modifications
            )
        }

        return nil
    }

    func presentRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            try? await prepareCache(editor: editor)
        }
        return nil
    }

    @WorkspaceActor
    func prepareCache(editor: EditorContent) async throws -> UpdatedContent? {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return nil }
        let (_, filespace) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        filespace.codeMetadata.uti = editor.uti
        filespace.codeMetadata.tabSize = editor.tabSize
        filespace.codeMetadata.indentSize = editor.indentSize
        filespace.codeMetadata.usesTabsForIndentation = editor.usesTabsForIndentation
        filespace.codeMetadata.guessLineEnding(from: editor.lines.first)
        return nil
    }

    func generateRealtimeSuggestions(editor: EditorContent) async throws -> UpdatedContent? {
        return try await presentSuggestions(editor: editor)
    }

    func promptToCode(editor: EditorContent) async throws -> UpdatedContent? {
        return nil
    }

    func customCommand(id: String, editor: EditorContent) async throws -> UpdatedContent? {
        Task {
            do {
                try await handleCustomCommand(id: id, editor: editor)
            } catch {
                print(error)
            }
        }
        return nil
    }
}

extension WindowBaseCommandHandler {
    func handleCustomCommand(id: String, editor: EditorContent) async throws {
        struct CommandNotFoundError: Error, LocalizedError {
            var errorDescription: String? { "Command not found" }
        }

        throw CommandNotFoundError()
    }
}

