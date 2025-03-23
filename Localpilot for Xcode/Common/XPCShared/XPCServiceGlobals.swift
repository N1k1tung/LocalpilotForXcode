//

import Foundation

@globalActor
public enum XPCServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

@XPCServiceActor
public func g_testXPCListenerEndpoint(_ endpoint: NSXPCListenerEndpoint) async -> Bool {
    let connection = NSXPCConnection(listenerEndpoint: endpoint)
    defer { connection.invalidate() }
    let stream: AsyncThrowingStream<Void, Error> = AsyncThrowingStream { continuation in
        _ = connection.remoteObjectProxyWithErrorHandler {
            continuation.finish(throwing: $0)
        }
        continuation.yield(())
        continuation.finish()
    }
    do {
        try await stream.first(where: { _ in true })!
        return true
    } catch {
        return false
    }
}
