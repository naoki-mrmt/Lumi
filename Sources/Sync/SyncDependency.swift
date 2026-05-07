// SyncDependency — SyncEngine の TCA Dependency 登録
//
// 本番では BufferedSyncEngine(LiveSyncEngine + LiveNetworkMonitor)。
// SupabaseClientProvider.shared が nil (Config 未設定) なら MockSyncEngine にフォールバック。

import Dependencies
import Foundation
import SupabaseClient

private enum SyncEngineKey: DependencyKey {
    static var liveValue: any SyncEngine {
        if let client = SupabaseClientProvider.shared {
            let live = LiveSyncEngine(client: client)
            let monitor = LiveNetworkMonitor()
            return BufferedSyncEngine(underlying: live, monitor: monitor)
        }
        return MockSyncEngine()
    }
    static let testValue: any SyncEngine = MockSyncEngine()
    static let previewValue: any SyncEngine = MockSyncEngine()
}

extension DependencyValues {
    public var syncEngine: any SyncEngine {
        get { self[SyncEngineKey.self] }
        set { self[SyncEngineKey.self] = newValue }
    }
}
