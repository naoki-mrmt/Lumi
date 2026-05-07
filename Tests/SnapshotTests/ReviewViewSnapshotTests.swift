// ReviewView の Snapshot Tests

#if os(iOS) && canImport(UIKit)
import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import ReviewFeature

@MainActor
@Suite("ReviewView Snapshots")
struct ReviewViewSnapshotTests {
    private func makeStore() -> StoreOf<ReviewFeature> {
        let (match, _) = SnapshotFixtures.basicMatch()
        return Store(initialState: ReviewFeature.State(match: match)) {
            ReviewFeature()
        }
    }

    @Test("ReviewView - Light Mode")
    func review_light() async {
        let host = UIHostingController(rootView: NavigationStack { ReviewView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .light
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }

    @Test("ReviewView - Dark Mode")
    func review_dark() async {
        let host = UIHostingController(rootView: NavigationStack { ReviewView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .dark
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }
}
#endif
