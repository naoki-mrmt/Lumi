import Testing
import Foundation
import ComposableArchitecture
@testable import Models
@testable import ReviewFeature

@MainActor
@Suite("ReviewFeature")
struct ReviewFeatureTests {
    @Test("onAppear で stats 計算")
    func on_appear() async {
        let match = Match(
            teamId: UUID(), recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: "X", matchType: .practice
        )
        let store = TestStore(initialState: ReviewFeature.State(match: match)) {
            ReviewFeature()
        }
        store.exhaustivity = .off
        await store.send(.onAppear)
        await store.receive(\.statsComputed, timeout: .seconds(2))
    }

    @Test("CSV 生成")
    func csv_generation() async {
        let match = Match(
            teamId: UUID(), recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: "X", matchType: .practice
        )
        let store = TestStore(initialState: ReviewFeature.State(match: match)) {
            ReviewFeature()
        }
        store.exhaustivity = .off
        await store.send(.generateCSVTapped)
        await store.receive(\.csvGenerated, timeout: .seconds(2)) { state in
            #expect(state.csvPlayerData != nil)
            #expect(state.csvLogData != nil)
        }
    }
}
