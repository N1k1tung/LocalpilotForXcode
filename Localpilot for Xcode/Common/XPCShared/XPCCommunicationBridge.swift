import Foundation

public enum XPCCommunicationBridgeError: Swift.Error, LocalizedError {
    case failedToCreateXPCConnection
    case xpcServiceError(Error)

    public var errorDescription: String? {
        switch self {
        case .failedToCreateXPCConnection:
            return "Failed to create XPC connection."
        case let .xpcServiceError(error):
            return "Connection to communication bridge error: \(error.localizedDescription)"
        }
    }
}

public class XPCCommunicationBridge {
    let service: BaseXPCService
    @XPCServiceActor
    var serviceEndpoint: NSXPCListenerEndpoint?

    public init() {
        service = .init(
            kind: .machService(
                identifier: Bundle(for: BaseXPCService.self)
                    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String +
                    ".CommunicationBridge"
            ),
            interface: NSXPCInterface(with: CommunicationBridgeXPCServiceProtocol.self)
        )
    }

    public func setDelegate(_ delegate: XPCServiceDelegate?) {
        service.delegate = delegate
    }

    @discardableResult
    public func launchExtensionServiceIfNeeded() async throws -> NSXPCListenerEndpoint? {
        try await withXPCServiceConnected { service, continuation in
            service.launchExtensionServiceIfNeeded { endpoint in
                continuation.resume(endpoint)
            }
        }
    }

    public func quit() async throws {
        try await withXPCServiceConnected { service, continuation in
            service.quit {
                continuation.resume(())
            }
        }
    }

    public func updateServiceEndpoint(_ endpoint: NSXPCListenerEndpoint) async throws {
        try await withXPCServiceConnected { service, continuation in
            service.updateServiceEndpoint(endpoint: endpoint) {
                continuation.resume(())
            }
        }
    }
}

extension XPCCommunicationBridge {
    @XPCServiceActor
    func withXPCServiceConnected<T>(
        _ fn: @escaping (CommunicationBridgeXPCServiceProtocol, AutoFinishContinuation<T>) -> Void
    ) async throws -> T {
        guard let connection = service.connection
        else { throw XPCCommunicationBridgeError.failedToCreateXPCConnection }
        do {
            return try await g_withXPCServiceConnected(connection: connection, fn)
        } catch {
            throw XPCCommunicationBridgeError.xpcServiceError(error)
        }
    }
}

