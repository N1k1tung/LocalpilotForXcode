import Foundation

public enum XPCExtensionServiceError: Swift.Error, LocalizedError {
    case failedToGetServiceEndpoint
    case failedToCreateXPCConnection
    case xpcServiceError(Error)

    public var errorDescription: String? {
        switch self {
        case .failedToGetServiceEndpoint:
            return "Waiting for service to connect to the communication bridge."
        case .failedToCreateXPCConnection:
            return "Failed to create XPC connection."
        case let .xpcServiceError(error):
            return "Connection to extension service error: \(error.localizedDescription)"
        }
    }
}

public class XPCExtensionService {
    @XPCServiceActor
    var service: BaseXPCService?
    @XPCServiceActor
    var connection: NSXPCConnection? { service?.connection }
    let bridge: XPCCommunicationBridge

    public nonisolated
    init() {
        bridge = XPCCommunicationBridge()
    }

    /// Launches the extension service if it's not running, returns true if the service has finished
    /// launching and the communication becomes available.
    @XPCServiceActor
    public func launchIfNeeded() async throws -> Bool {
        try await bridge.launchExtensionServiceIfNeeded() != nil
    }

    public func getXPCServiceVersion() async throws -> (version: String, build: String) {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceVersion { version, build in
                continuation.resume((version, build))
            }
        }
    }

    public func getXPCServiceAccessibilityPermission() async throws -> ObservedAXStatus {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceAccessibilityPermission { isGranted in
                continuation.resume(isGranted)
            }
        }
    }
    
    public func getXPCServiceExtensionPermission() async throws -> ExtensionPermissionStatus {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceExtensionPermission { isGranted in
                continuation.resume(isGranted)
            }
        }
    }

    public func getSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { $0.getSuggestedCode }
        )
    }

    public func getNextSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { $0.getNextSuggestedCode }
        )
    }

    public func getPreviousSuggestedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getPreviousSuggestedCode }
        )
    }

    public func getSuggestionAcceptedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getSuggestionAcceptedCode }
        )
    }

    public func getSuggestionRejectedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getSuggestionRejectedCode }
        )
    }

    public func getRealtimeSuggestedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getRealtimeSuggestedCode }
        )
    }

    public func prefetchRealtimeSuggestions(editorContent: EditorContent) async {
        guard let data = try? JSONEncoder().encode(editorContent) else { return }
        try? await withXPCServiceConnected { service, continuation in
            service.prefetchRealtimeSuggestions(editorContent: data) {
                continuation.resume(())
            }
        }
    }

    public func customCommand(
        id: String,
        editorContent: EditorContent
    ) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { service in { service.customCommand(id: id, editorContent: $0, withReply: $1) } }
        )
    }


    public func quitService() async throws {
        try await withXPCServiceConnectedWithoutLaunching {
            service, continuation in
            service.quit {
                continuation.resume(())
            }
        }
    }

    public func postNotification(name: String) async throws {
        try await withXPCServiceConnected {
            service, continuation in
            service.postNotification(name: name) {
                continuation.resume(())
            }
        }
    }

    public func send<M: ExtensionServiceRequestType>(
        requestBody: M
    ) async throws -> M.ResponseBody {
        try await withXPCServiceConnected { service, continuation in
            do {
                let requestBodyData = try JSONEncoder().encode(requestBody)
                service.send(endpoint: M.endpoint, requestBody: requestBodyData) { data, error in
                    if let error {
                        continuation.reject(error)
                    } else {
                        do {
                            guard let data = data else {
                                continuation.reject(NoDataError())
                                return
                            }
                            let responseBody = try JSONDecoder().decode(
                                M.ResponseBody.self,
                                from: data
                            )
                            continuation.resume(responseBody)
                        } catch {
                            continuation.reject(error)
                        }
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
}

extension XPCExtensionService: XPCServiceDelegate {
    public func connectionDidInterrupt() async {
        Task { @XPCServiceActor in
            service = nil
        }
    }

    public func connectionDidInvalidate() async {
        Task { @XPCServiceActor in
            service = nil
        }
    }
}

extension XPCExtensionService {
    @XPCServiceActor
    private func updateEndpoint(_ endpoint: NSXPCListenerEndpoint) {
        service = BaseXPCService(
            kind: .anonymous(endpoint: endpoint),
            interface: NSXPCInterface(with: XPCServiceProtocol.self),
            delegate: self
        )
    }

    @XPCServiceActor
    private func withXPCServiceConnected<T>(
        _ fn: @escaping (XPCServiceProtocol, AutoFinishContinuation<T>) -> Void
    ) async throws -> T {
        if let service, let connection = service.connection {
            do {
                return try await g_withXPCServiceConnected(connection: connection, fn)
            } catch {
                throw XPCExtensionServiceError.xpcServiceError(error)
            }
        } else {
            guard let endpoint = try await bridge.launchExtensionServiceIfNeeded()
            else { throw XPCExtensionServiceError.failedToGetServiceEndpoint }
            updateEndpoint(endpoint)

            if let service, let connection = service.connection {
                do {
                    return try await g_withXPCServiceConnected(connection: connection, fn)
                } catch {
                    throw XPCExtensionServiceError.xpcServiceError(error)
                }
            } else {
                throw XPCExtensionServiceError.failedToCreateXPCConnection
            }
        }
    }
    
    @XPCServiceActor
    private func withXPCServiceConnectedWithoutLaunching<T>(
        _ fn: @escaping (XPCServiceProtocol, AutoFinishContinuation<T>) -> Void
    ) async throws -> T {
        if let service, let connection = service.connection {
            do {
                return try await g_withXPCServiceConnected(connection: connection, fn)
            } catch {
                throw XPCExtensionServiceError.xpcServiceError(error)
            }
        }
        throw XPCExtensionServiceError.failedToCreateXPCConnection
    }

    @XPCServiceActor
    private func suggestionRequest(
        _ editorContent: EditorContent,
        _ fn: @escaping (any XPCServiceProtocol) -> (Data, @escaping (Data?, Error?) -> Void)
            -> Void
    ) async throws -> UpdatedContent? {
        let data = try JSONEncoder().encode(editorContent)
        return try await withXPCServiceConnected {
            service, continuation in
            fn(service)(data) { updatedData, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                do {
                    if let updatedData {
                        let updatedContent = try JSONDecoder()
                            .decode(UpdatedContent.self, from: updatedData)
                        continuation.resume(updatedContent)
                    } else {
                        continuation.resume(nil)
                    }
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
}

@XPCServiceActor
func g_withXPCServiceConnected<T, P>(
    connection: NSXPCConnection,
    _ fn: @escaping (P, AutoFinishContinuation<T>) -> Void
) async throws -> T {
    let stream: AsyncThrowingStream<T, Error> = AsyncThrowingStream { continuation in
        let service = connection.remoteObjectProxyWithErrorHandler {
            continuation.finish(throwing: $0)
        } as! P
        fn(service, .init(continuation: continuation))
    }
    for try await result in stream {
        return result
    }
    throw XPCExtensionServiceError.failedToCreateXPCConnection
}
