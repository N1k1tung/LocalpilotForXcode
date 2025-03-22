import Combine
import Foundation

@globalActor public enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

/// The running extension service.
public final class Service {
    public static let shared = Service()

    @WorkspaceActor
    let workspacePool: WorkspacePool
    public let realtimeSuggestionController = RealtimeSuggestionController()
    public let scheduledCleaner: ScheduledCleaner
    let keyBindingManager: KeyBindingManager

    var cancellable = Set<AnyCancellable>()

    private init() {
        var workspacePool = WorkspacePool.shared

        scheduledCleaner = .init()
        workspacePool.registerPlugin {
            SuggestionServiceWorkspacePlugin(workspace: $0) { SuggestionService.service() }
        }
        self.workspacePool = workspacePool

        keyBindingManager = .init(
            workspacePool: workspacePool,
            acceptSuggestion: {
                Task { await PseudoCommandHandler().acceptSuggestion() }
            },
            expandSuggestion: {
                if !ExpandableSuggestionService.shared.isSuggestionExpanded {
                    ExpandableSuggestionService.shared.isSuggestionExpanded = true
                }
            },
            collapseSuggestion: {
                if ExpandableSuggestionService.shared.isSuggestionExpanded {
                    ExpandableSuggestionService.shared.isSuggestionExpanded = false
                }
            },
            dismissSuggestion: {
                Task { await PseudoCommandHandler().dismissSuggestion() }
            }
        )
        let scheduledCleaner = ScheduledCleaner()

        scheduledCleaner.service = self
    }

    @MainActor
    public func start() {
        scheduledCleaner.start()
        realtimeSuggestionController.start()
        globalShortcutManager.start()
        keyBindingManager.start()

        Task {
            await XcodeInspector.shared.safe.$activeDocumentURL
                .removeDuplicates()
                .filter { $0 != .init(fileURLWithPath: "/") }
                .compactMap { $0 }
                .sink { [weak self] fileURL in
                    Task {
                        do {
                            try await self?.workspacePool
                                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
                        } catch {
                            print(error)
                        }
                    }
                }.store(in: &cancellable)
            
//            await XcodeInspector.shared.safe.$activeWorkspaceURL.receive(on: DispatchQueue.main)
//                .sink { newURL in
//                    if let path = newURL?.path, path != "/", self.guiController.store.chatHistory.selectedWorkspacePath != path {
//                        let name = self.getDisplayNameOfXcodeWorkspace(url: newURL!)
//                        self.guiController.store.send(.switchWorkspace(path: path, name: name))
//                    }
//                    
//                }.store(in: &cancellable)
        }
    }

    @MainActor
    public func prepareForExit() async {
        dprint("Prepare for exit.")
        keyBindingManager.stopForExit()
        await scheduledCleaner.closeAllChildProcesses()
    }

    private func getDisplayNameOfXcodeWorkspace(url: URL) -> String {
        var name = url.lastPathComponent
        let suffixes = [".xcworkspace", ".xcodeproj"]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name
    }
}

public extension Service {
    func handleXPCServiceRequests(
        endpoint: String,
        requestBody: Data,
        reply: @escaping (Data?, Error?) -> Void
    ) {
        reply(nil, XPCRequestNotHandledError())
    }
}

