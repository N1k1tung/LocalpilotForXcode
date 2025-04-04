import AppKit

/// It's used to run some commands without really triggering the menu bar item.
///
/// For example, we can use it to generate real-time suggestions without Apple Scripts.
/// TODO: cleanup unnecessary gui presentation and related logic
struct PseudoCommandHandler {
    static var lastTimeCommandFailedToTriggerWithAccessibilityAPI = Date(timeIntervalSince1970: 0)
    static var lastBundleNotFoundTime = Date(timeIntervalSince1970: 0)
    static var lastBundleDisabledTime = Date(timeIntervalSince1970: 0)
//    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    func presentPreviousSuggestion() async {

    }

    func presentNextSuggestion() async {

    }

    @WorkspaceActor
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {
        guard let filespace = await getFilespace(),
              let (workspace, _) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: filespace.fileURL) else { return }

        if Task.isCancelled { return }

        // Can't use handler if content is not available.
        guard let editor = await getEditorContent(sourceEditor: sourceEditor)
        else { return }

        let fileURL = filespace.fileURL
        
        if filespace.presentingSuggestion != nil {
            // Check if the current suggestion is still valid.
            if filespace.validateSuggestions(
                lines: editor.lines,
                cursorPosition: editor.cursorPosition
            ) {
                return
            } else {
//                presenter.discardSuggestion(fileURL: filespace.fileURL)
            }
        }

        do {
            try await workspace.generateSuggestions(
                forFileAt: fileURL,
                editor: editor
            )
            if let sourceEditor {
                let editorContent = sourceEditor.getContent()
                _ = filespace.validateSuggestions(
                    lines: editorContent.lines,
                    cursorPosition: editorContent.cursorPosition
                )
            }
            if !filespace.errorMessage.isEmpty {
//                presenter
//                    .presentWarningMessage(
//                        filespace.errorMessage,
//                        url: "https://github.com/github-copilot/signup/copilot_individual"
//                    )
            }
            if filespace.presentingSuggestion != nil {
//                presenter.presentSuggestion(fileURL: fileURL)
                workspace.notifySuggestionShown(fileFileAt: fileURL)
            } else {
//                presenter.discardSuggestion(fileURL: fileURL)
            }
        } catch {
            return
        }
    }

    @WorkspaceActor
    func invalidateRealtimeSuggestionsIfNeeded(fileURL: URL, sourceEditor: SourceEditor) async {
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL) else { return }

        if filespace.presentingSuggestion == nil {
            return // skip if there's no suggestion presented.
        }

        let content = sourceEditor.getContent()
        if !filespace.validateSuggestions(
            lines: content.lines,
            cursorPosition: content.cursorPosition
        ) {
//            PresentInWindowSuggestionPresenter().discardSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestions() async {
        _ = try? await rejectSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    @WorkspaceActor
    private func rejectSuggestion(editor: EditorContent) async throws {
        guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
        else { return }

        let (workspace, _) = try await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        workspace.rejectSuggestion(forFileAt: fileURL, editor: editor)
    }

    func acceptSuggestion() async {
        do {
            try await XcodeInspector.shared.safe.latestActiveXcode?
                .triggerCopilotCommand(name: "Accept Suggestion")
        } catch {
            let lastBundleNotFoundTime = Self.lastBundleNotFoundTime
            let lastBundleDisabledTime = Self.lastBundleDisabledTime
            let now = Date()
            if let cantRunError = error as? AppInstanceInspector.CantRunCommand {
                if cantRunError.errorDescription.contains("No bundle found") {
                    // Extension permission not granted
                    if now.timeIntervalSince(lastBundleNotFoundTime) > 60 * 60 {
                        Self.lastBundleNotFoundTime = now
                        //                            toast.toast(
                        //                                title: "GitHub Copilot Extension Permission Not Granted",
                        //                                content: """
                        //                                Enable Extensions → Xcode Source Editor → GitHub Copilot \
                        //                                for Xcode for faster and full-featured code completion. \
                        //                                [View How-to Guide](https://github.com/github/CopilotForXcode/blob/main/TROUBLESHOOTING.md#extension-permission)
                        //                                """,
                        //                                level: .warning,
                        //                                button: .init(
                        //                                    title: "Enable",
                        //                                    action: { NSWorkspace.openXcodeExtensionsPreferences() }
                        //                                )
                        //                            )
                    }
                } else if cantRunError.errorDescription.contains("found but disabled") {
                    if now.timeIntervalSince(lastBundleDisabledTime) > 60 * 60 {
                        Self.lastBundleDisabledTime = now
                        //                            toast.toast(
                        //                                title: "GitHub Copilot Extension Disabled",
                        //                                content: "Quit and restart Xcode to enable extension.",
                        //                                level: .warning,
                        //                                button: .init(
                        //                                    title: "Restart Xcode",
                        //                                    action: { NSWorkspace.restartXcode() }
                        //                                )
                        //                            )
                    }
                }
            }
        }
    }

    func dismissSuggestion() async {
        guard let documentURL = await XcodeInspector.shared.safe.activeDocumentURL else { return }
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: documentURL) else { return }

        await filespace.reset()
    }

}

extension PseudoCommandHandler {

    func getFileContent(sourceEditor: AXUIElement?) async
    -> (
        content: String,
        lines: [String],
        selections: [CursorRange],
        cursorPosition: CursorPosition,
        cursorOffset: Int
    )?
    {
        guard let xcode = ActiveApplicationMonitor.shared.activeXcode
                ?? ActiveApplicationMonitor.shared.latestXcode else { return nil }
        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        guard let focusElement = sourceEditor ?? application.focusedElement,
              focusElement.description == "Source Editor"
        else { return nil }
        guard let selectionRange = focusElement.selectedTextRange else { return nil }
        let content = focusElement.value
        let split = content.breakLines(appendLineBreakToLastLine: false)
        let range = SourceEditor.convertRangeToCursorRange(selectionRange, in: content)
        return (content, split, [range], range.start, selectionRange.lowerBound)
    }

    func getFileURL() async -> URL? {
        await XcodeInspector.shared.safe.realtimeActiveDocumentURL
    }

    @WorkspaceActor
    func getFilespace() async -> Filespace? {
        guard
            let fileURL = await getFileURL(),
            let (_, filespace) = try? await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        else { return nil }
        return filespace
    }

    @WorkspaceActor
    func getEditorContent(sourceEditor: SourceEditor?) async -> EditorContent? {
        guard let filespace = await getFilespace(),
              let sourceEditor = await {
                  if let sourceEditor { sourceEditor }
                  else { await XcodeInspector.shared.safe.focusedEditor }
              }()
        else { return nil }
        if Task.isCancelled { return nil }
        let content = sourceEditor.getContent()
        let uti = filespace.codeMetadata.uti ?? ""
        let tabSize = filespace.codeMetadata.tabSize ?? 4
        let indentSize = filespace.codeMetadata.indentSize ?? 4
        let usesTabsForIndentation = filespace.codeMetadata.usesTabsForIndentation ?? false
        return .init(
            content: content.content,
            lines: content.lines,
            uti: uti,
            cursorPosition: content.cursorPosition,
            cursorOffset: content.cursorOffset,
            selections: content.selections.map {
                .init(start: $0.start, end: $0.end)
            },
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
    }
}

