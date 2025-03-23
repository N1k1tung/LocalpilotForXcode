import Foundation

class XPCService {
    enum Kind {
        case machService(identifier: String)
        case anonymous(endpoint: NSXPCListenerEndpoint)
    }

    let kind: Kind
    let interface: NSXPCInterface
    weak var delegate: XPCServiceDelegate?
    
    @XPCServiceActor
    private var isInvalidated = false

    @XPCServiceActor
    private lazy var _connection: InvalidatingConnection? = buildConnection()

    @XPCServiceActor
    var connection: NSXPCConnection? {
        if isInvalidated { _connection = nil }
        if _connection == nil { rebuildConnection() }
        return _connection?.connection
    }

    init(
        kind: Kind,
        interface: NSXPCInterface,
        delegate: XPCServiceDelegate? = nil
    ) {
        self.kind = kind
        self.interface = interface
        self.delegate = delegate
    }

    @XPCServiceActor
    private func buildConnection() -> InvalidatingConnection {
        let connection = switch kind {
        case let .machService(name):
            NSXPCConnection(machServiceName: name)
        case let .anonymous(endpoint):
            NSXPCConnection(listenerEndpoint: endpoint)
        }
        connection.remoteObjectInterface = interface
        connection.invalidationHandler = { [weak self] in
            Task { [weak self] in
                self?.markAsInvalidated()
                await self?.delegate?.connectionDidInvalidate()
            }
        }
        connection.interruptionHandler = { [weak self] in
            print("XPCService interrupted")
            Task { [weak self] in
                await self?.delegate?.connectionDidInterrupt()
            }
        }
        connection.resume()
        return .init(connection)
    }

    @XPCServiceActor
    private func markAsInvalidated() {
        isInvalidated = true
    }

    @XPCServiceActor
    private func rebuildConnection() {
        _connection = buildConnection()
    }
}

public protocol XPCServiceDelegate: AnyObject {
    func connectionDidInvalidate() async
    func connectionDidInterrupt() async
}

private class InvalidatingConnection {
    let connection: NSXPCConnection
    init(_ connection: NSXPCConnection) {
        self.connection = connection
    }

    deinit {
        connection.invalidationHandler = {}
        connection.interruptionHandler = {}
        connection.invalidate()
    }
}

struct NoDataError: Error {}

struct AutoFinishContinuation<T> {
    var continuation: AsyncThrowingStream<T, Error>.Continuation

    func resume(_ value: T) {
        continuation.yield(value)
        continuation.finish()
    }

    func reject(_ error: Error) {
        if (error as NSError).code == -100 {
            continuation.finish(throwing: CancellationError())
        } else {
            continuation.finish(throwing: error)
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
