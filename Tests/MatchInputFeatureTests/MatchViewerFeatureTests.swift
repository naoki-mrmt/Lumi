// MatchViewerFeature が動作することを TestStore で検証
// (テスト target を別途切らず、MatchInputFeatureTests target に同居)

import Testing
import Foundation
import ComposableArchitecture
@testable import Models
@testable import StatsEngine
import MatchViewerFeature

@MainActor
@Suite("MatchViewerFeature")
struct MatchViewerFeatureTests {
    @Test("onAppear で stats が再計算される")
    func on_appear_recomputes() async {
        let teamId = UUID()
        let matchId = UUID()
        let setId = UUID()
        let attacker = UUID()
        let rally = Rally(
            id: UUID(),
            setId: setId,
            rallyNumber: 1,
            startScoreUs: 0,
            startScoreOpp: 0,
            servingTeam: .own,
            plays: [
                Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playerId: attacker, playType: .attack, evaluation: .excellent)
            ]
        )
        let set = MatchSet(id: setId, matchId: matchId, setNumber: 1, formation: .f5_1_3, rallies: [rally])
        let match = Match(
            id: matchId, teamId: teamId, recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: "対戦相手", matchType: .practice,
            sets: [set]
        )

        let store = TestStore(initialState: MatchViewerFeature.State(match: match)) {
            MatchViewerFeature()
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.statsRecomputed, timeout: .seconds(2)) { state in
            #expect(state.ownStats.attackAttempts == 1)
            #expect(state.ownStats.attackKillRate == 100.0)
        }
    }

    @Test("scopeChanged で statsScope 変化")
    func scope_change() async {
        let match = Match(
            teamId: UUID(), recorderId: UUID(),
            matchCode: "X", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: "X", matchType: .practice
        )

        let store = TestStore(initialState: MatchViewerFeature.State(match: match)) {
            MatchViewerFeature()
        }
        store.exhaustivity = .off

        await store.send(.scopeChanged(.set(2))) { state in
            #expect(state.statsScope == .set(2))
        }
    }
}
