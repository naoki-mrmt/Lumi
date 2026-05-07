// NetworkMonitor — オフライン検知の抽象化
//
// Live: NWPathMonitor をラップ
// Mock: テスト用に固定値や AsyncStream を注入

import Foundation
#if canImport(Network)
import Network
#endif

public protocol NetworkMonitor: Sendable {
    func currentStatus() async -> Bool
    func observe() -> AsyncStream<Bool>
    func start() async
    func stop() async
}

private struct ContinuationStore {
    var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    var lastStatus: Bool = true

    mutating func update(_ status: Bool) {
        lastStatus = status
        for c in continuations.values { c.yield(status) }
    }
}

public actor MockNetworkMonitor: NetworkMonitor {
    private var store = ContinuationStore()

    public init(initial: Bool = true) {
        self.store.lastStatus = initial
    }

    public func setStatus(_ online: Bool) {
        store.update(online)
    }

    public func currentStatus() -> Bool {
        store.lastStatus
    }

    public nonisolated func observe() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<Bool>.Continuation) {
        store.continuations[id] = continuation
        continuation.yield(store.lastStatus)
    }

    private func unregister(id: UUID) {
        store.continuations.removeValue(forKey: id)
    }

    public func start() {}
    public func stop() {}
}

#if canImport(Network)
public actor LiveNetworkMonitor: NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.muramoto-co.lumi.networkmonitor")
    private var store = ContinuationStore()

    public init() {}

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { await self?.handle(online: online) }
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
    }

    private func handle(online: Bool) {
        store.update(online)
    }

    public func currentStatus() -> Bool {
        store.lastStatus
    }

    public nonisolated func observe() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(id: UUID, continuation: AsyncStream<Bool>.Continuation) {
        store.continuations[id] = continuation
        continuation.yield(store.lastStatus)
    }

    private func unregister(id: UUID) {
        store.continuations.removeValue(forKey: id)
    }
}
#endif
