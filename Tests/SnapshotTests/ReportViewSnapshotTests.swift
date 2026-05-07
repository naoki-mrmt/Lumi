// ReportView の Snapshot Tests

#if os(iOS) && canImport(UIKit)
import ComposableArchitecture
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import ReportFeature

@MainActor
@Suite("ReportView Snapshots")
struct ReportViewSnapshotTests {
    private func makeStore() -> StoreOf<ReportFeature> {
        let (match, _) = SnapshotFixtures.basicMatch()
        return Store(initialState: ReportFeature.State(matches: [match])) {
            ReportFeature()
        }
    }

    @Test("ReportView - Light Mode")
    func report_light() async {
        let host = UIHostingController(rootView: NavigationStack { ReportView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .light
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }

    @Test("ReportView - Dark Mode")
    func report_dark() async {
        let host = UIHostingController(rootView: NavigationStack { ReportView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .dark
        assertSnapshot(of: host, as: .image(on: .iPadPro12_9))
    }
}
#endif
