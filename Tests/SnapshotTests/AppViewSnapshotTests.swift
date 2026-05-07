// AppView の Snapshot Tests (iPad Pro 12.9" / Light + Dark)

#if os(iOS) && canImport(UIKit)
import ComposableArchitecture
import LocalStore
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import AppFeature

@MainActor
@Suite("AppView Snapshots")
struct AppViewSnapshotTests {
    private func makeStore() -> StoreOf<AppFeature> {
        withDependencies {
            $0.localStore = .inMemory()
        } operation: {
            Store(initialState: AppFeature.State()) {
                AppFeature()
            }
        }
    }

    @Test("AppView - Light Mode")
    func appView_light() async {
        let host = UIHostingController(rootView: NavigationStack { AppView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .light
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }

    @Test("AppView - Dark Mode")
    func appView_dark() async {
        let host = UIHostingController(rootView: NavigationStack { AppView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .dark
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }
}
#endif
