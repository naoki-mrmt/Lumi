// MatchViewerView の Snapshot Tests

#if os(iOS) && canImport(UIKit)
import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import MatchViewerFeature

@MainActor
@Suite("MatchViewerView Snapshots")
struct MatchViewerViewSnapshotTests {
    private func makeStore() -> StoreOf<MatchViewerFeature> {
        let (match, _) = SnapshotFixtures.basicMatch()
        return Store(initialState: MatchViewerFeature.State(match: match)) {
            MatchViewerFeature()
        }
    }

    @Test("MatchViewerView - Light Mode")
    func matchViewer_light() async {
        let host = UIHostingController(rootView: NavigationStack { MatchViewerView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .light
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }

    @Test("MatchViewerView - Dark Mode")
    func matchViewer_dark() async {
        let host = UIHostingController(rootView: NavigationStack { MatchViewerView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .dark
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }
}
#endif
