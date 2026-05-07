// AppView の Snapshot Tests (iPad Pro 13" / Light + Dark)

#if os(iOS) && canImport(UIKit)
import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import AppFeature

@MainActor
@Suite("AppView Snapshots", .disabled("初回は SnapshotsRecording.recordingMode を有効にして記録する。記録後 disabled を外す"))
struct AppViewSnapshotTests {
    @Test("AppView - Light Mode")
    func appView_light() async {
        let store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
        let view = NavigationStack { AppView(store: store) }
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = .light
        assertSnapshot(of: host, as: .image(on: .iPadPro13))
    }

    @Test("AppView - Dark Mode")
    func appView_dark() async {
        let store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
        let view = NavigationStack { AppView(store: store) }
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = .dark
        assertSnapshot(of: host, as: .image(on: .iPadPro13))
    }
}
#endif
