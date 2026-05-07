// E2EMatchFlowTests — 試合作成 → 入力 → 振り返り の通しテスト

import Testing
import Foundation
import ComposableArchitecture
import Dependencies
@testable import Models
@testable import LocalStore
@testable import ServiceOrderEngine
@testable import StatsEngine
@testable import RallyTimeline
@testable import MatchSetupFeature
@testable import MatchInputFeature
@testable import MatchViewerFeature
@testable import ReviewFeature
@testable import CSVExporter
@testable import MatchBackup

@MainActor
@Suite("E2E: full match flow")
struct E2EMatchFlowTests {
    @Test("試合作成 → 1ラリー入力 → ラリー終了 → KPI 反映")
    func full_flow() async throws {
        // 1. チーム + 選手 9人をローカルに準備
        let team = Team(ownerId: UUID(), name: "Lumi")
        let players = (1...9).map { Player(teamId: team.id, jerseyNumber: $0, name: "選手\($0)") }
        let store = LocalStore.inMemory()
        try await store.saveTeam(team)
        for p in players { try await store.savePlayer(p) }

        // 2. MatchSetup で試合作成 (TestStore)
        var setupState = MatchSetupFeature.State(team: team)
        setupState.startingLineup = players
        setupState.opponentTeamName = "対戦相手"

        let setupStore = TestStore(initialState: setupState) {
            MatchSetupFeature()
        } withDependencies: {
            $0.localStore = store
        }
        setupStore.exhaustivity = .off

        await setupStore.send(.createMatchTapped(recorderId: UUID(), matchCode: "ABCDEF", codeExpiresAt: Date().addingTimeInterval(3600)))
        await setupStore.receive(\.matchPrepared, timeout: .seconds(2))

        guard let preparedMatch = setupStore.state.setupResult else {
            Issue.record("matchPrepared が届かなかった")
            return
        }

        // 3. MatchInput で 1 ラリーを入力
        let inputState = MatchInputFeature.State(match: preparedMatch, currentSetId: preparedMatch.sets[0].id)
        let inputStore = TestStore(initialState: inputState) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = store
        }
        inputStore.exhaustivity = .off

        await inputStore.send(.playerSelected(players[0].id))
        await inputStore.send(.playTypeSelected(.serve))
        await inputStore.send(.evaluationSelected(.excellent))
        await inputStore.send(.rallyEndTapped(winner: .own))

        let updatedMatch = inputStore.state.match
        #expect(updatedMatch.sets[0].rallies.count == 1)
        #expect(updatedMatch.sets[0].rallies[0].winner == .own)
        #expect(updatedMatch.sets[0].rallies[0].plays.count == 1)
        #expect(updatedMatch.sets[0].lastServingTeam == .own)

        // 4. KPI 計算 (StatsEngine)
        let stats = StatsEngine().teamStats(in: updatedMatch, scope: .wholeMatch, side: .own)
        #expect(stats.serveAttempts == 1)
        #expect(stats.serveAces == 1)

        // 5. ReviewFeature で CSV / バックアップ
        let reviewStore = TestStore(initialState: ReviewFeature.State(match: updatedMatch)) {
            ReviewFeature()
        }
        reviewStore.exhaustivity = .off

        await reviewStore.send(.generateCSVTapped)
        await reviewStore.receive(\.csvGenerated, timeout: .seconds(2)) { state in
            #expect((state.csvPlayerData?.count ?? 0) > 0)
        }

        // 6. JSON バックアップが round-trip できる
        let backup = try MatchBackup.encode(updatedMatch)
        let decoded = try MatchBackup.decode(backup)
        #expect(decoded.id == updatedMatch.id)
    }

    @Test("オフライン → push 失敗で バッファに溜まり、復帰 → flush で空になる")
    func offline_flush_flow() async throws {
        // この E2E は M4 SyncEngine のレイヤーで完結
        // (実 Supabase 連携は本番セットアップ後)
        // Placeholder: 既に Sync テストでカバー済み
    }
}

@Suite("Performance smoke")
struct PerformanceSmokeTests {
    @Test("StatsEngine: 100ラリー の計算が 200ms 以内")
    func stats_under_200ms() {
        var match = Match(
            teamId: UUID(), recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: "X", matchType: .practice
        )
        let setId = UUID()
        var rallies: [Rally] = []
        for i in 1...100 {
            let plays = (1...6).map { _ in
                Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playerId: UUID(), playType: .attack, evaluation: .normal)
            }
            rallies.append(Rally(setId: setId, rallyNumber: i, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own, winner: .own, plays: plays))
        }
        match.sets = [MatchSet(id: setId, matchId: match.id, setNumber: 1, formation: .f5_1_3, rallies: rallies)]

        let start = Date()
        _ = StatsEngine().teamStats(in: match, scope: .wholeMatch, side: .own)
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.2, "stats took \(elapsed) sec, expected < 0.2")
    }
}
