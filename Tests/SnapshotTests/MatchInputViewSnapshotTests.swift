// MatchInputView の Snapshot Tests

#if os(iOS) && canImport(UIKit)
import ComposableArchitecture
import LocalStore
import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import MatchInputFeature

@MainActor
@Suite("MatchInputView Snapshots", .disabled("初回は recordingMode を有効にして記録する"))
struct MatchInputViewSnapshotTests {
    private func makeStore() -> StoreOf<MatchInputFeature> {
        let (match, _) = SnapshotFixtures.basicMatch()
        return withDependencies {
            $0.localStore = .inMemory()
        } operation: {
            Store(initialState: MatchInputFeature.State(match: match, currentSetId: match.sets[0].id)) {
                MatchInputFeature()
            }
        }
    }

    @Test("MatchInputView - Light Mode")
    func matchInput_light() async {
        let host = UIHostingController(rootView: NavigationStack { MatchInputView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .light
        assertSnapshot(of: host, as: .image(on: .iPadPro13))
    }

    @Test("MatchInputView - Dark Mode")
    func matchInput_dark() async {
        let host = UIHostingController(rootView: NavigationStack { MatchInputView(store: makeStore()) })
        host.overrideUserInterfaceStyle = .dark
        assertSnapshot(of: host, as: .image(on: .iPadPro13))
    }
}
#endif
