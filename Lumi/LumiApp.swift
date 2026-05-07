import SwiftUI
import SwiftData
import ComposableArchitecture
import Dependencies
import AppFeature
import LocalStore
import SupabaseClient
import Telemetry

@main
struct LumiApp: App {
    init() {
        // Sentry / OSLog 初期化 (DSN 未設定なら no-op)
        Telemetry.start(
            dsn: AppConfig.sentryDSN,
            environment: AppConfig.environment,
            tracesSampleRate: AppConfig.environment == "production" ? 0.1 : 1.0
        )
    }

    @MainActor
    private static let storeAndContainer: (StoreOf<AppFeature>, ModelContainer) = {
        do {
            let container = try SwiftDataStore.makeContainer(inMemory: false)
            let dataStore = SwiftDataStore(container: container)
            let local = LocalStore.swiftData(dataStore)
            let store = withDependencies {
                $0.localStore = local
            } operation: {
                Store(initialState: AppFeature.State(isAuthRequired: AppConfig.isConfigured)) {
                    AppFeature()
                }
            }
            return (store, container)
        } catch {
            fatalError("ModelContainer 初期化失敗: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppView(store: Self.storeAndContainer.0)
        }
        .modelContainer(Self.storeAndContainer.1)
    }
}
