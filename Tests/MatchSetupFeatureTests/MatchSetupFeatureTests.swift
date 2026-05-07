import Testing
import Foundation
import ComposableArchitecture
import Dependencies
@testable import Models
@testable import LocalStore
@testable import MatchSetupFeature

@MainActor
@Suite("MatchSetupFeature: lineup")
struct MatchSetupFeatureLineupTests {
    @Test("選手をタップ→ lineup に追加 / 再タップで削除")
    func toggle_player_in_lineup() async throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let p = Player(teamId: team.id, jerseyNumber: 1, name: "選手1")

        let store = TestStore(initialState: MatchSetupFeature.State(team: team)) {
            MatchSetupFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }

        await store.send(.togglePlayerInLineup(p)) {
            $0.startingLineup = [p]
        }

        await store.send(.togglePlayerInLineup(p)) {
            $0.startingLineup = []
        }
    }

    @Test("lineup が9人埋まっていれば追加されない")
    func lineup_capped_at_9() async throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let players = (1...10).map { Player(teamId: team.id, jerseyNumber: $0, name: "選手\($0)") }

        let store = TestStore(initialState: MatchSetupFeature.State(team: team)) {
            MatchSetupFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }

        for p in players.prefix(9) {
            await store.send(.togglePlayerInLineup(p)) {
                $0.startingLineup.append(p)
            }
        }
        // 10人目はスキップ
        await store.send(.togglePlayerInLineup(players[9]))  // no state change
    }
}

@MainActor
@Suite("MatchSetupFeature: copy from last match")
struct MatchSetupFeatureCopyTests {
    @Test("直近試合がない場合、コピーは何もしない")
    func no_last_match() async throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let store = TestStore(initialState: MatchSetupFeature.State(team: team)) {
            MatchSetupFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        await store.send(.copyFromLastMatchTapped)
        // どのアクションも届かない (no last match)
        await store.finish()
    }

    @Test("直近試合があれば lineup と formation が反映される")
    func copy_from_last_match() async throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let players = (1...9).map { Player(teamId: team.id, jerseyNumber: $0, name: "選手\($0)") }

        // 既存試合: starters 9人、サービス順 1..9
        let matchSeed: Match = {
            var m = Match(
                teamId: team.id,
                recorderId: UUID(),
                matchCode: "ABCDEF",
                matchCodeExpiresAt: Date(),
                date: Date(),
                startTime: Date(),
                opponentTeamName: "対戦相手",
                matchType: .practice
            )
            m.members = players.map { MatchMember(matchId: m.id, playerId: $0.id, isStarter: true) }
            m.serviceOrders = players.enumerated().map {
                ServiceOrderEntry(matchId: m.id, order: $0.offset + 1, startingPlayerId: $0.element.id)
            }
            m.sets = [MatchSet(matchId: m.id, setNumber: 1, formation: .f6_3)]
            return m
        }()

        let store = TestStore(initialState: MatchSetupFeature.State(team: team)) {
            MatchSetupFeature()
        } withDependencies: {
            let inmemory = LocalStore.inMemory()
            // 選手と試合を seed
            $0.localStore = LocalStore(
                fetchTeams: inmemory.fetchTeams,
                saveTeam: inmemory.saveTeam,
                fetchPlayers: { _ in players },
                savePlayer: inmemory.savePlayer,
                deletePlayer: inmemory.deletePlayer,
                fetchMatches: inmemory.fetchMatches,
                saveMatch: inmemory.saveMatch,
                fetchLastMatch: { _ in matchSeed }
            )
        }

        await store.send(.copyFromLastMatchTapped)
        await store.receive(.lineupCopied(lineup: players, formation: .f6_3)) {
            $0.startingLineup = players
            $0.formation = .f6_3
        }
    }
}

@MainActor
@Suite("MatchSetupFeature: createMatch")
struct MatchSetupFeatureCreateTests {
    @Test("9人未満で createMatchTapped → エラー表示")
    func not_enough_players() async throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let store = TestStore(initialState: MatchSetupFeature.State(team: team)) {
            MatchSetupFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }

        await store.send(.createMatchTapped(recorderId: UUID(), matchCode: "ABCDEF", codeExpiresAt: Date())) {
            $0.errorMessage = "スタメン9人を選択してください"
        }
    }

    @Test("9人 + 対戦相手名あり → matchPrepared、ServiceOrderEntry が9件")
    func create_success() async throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let players = (1...9).map { Player(teamId: team.id, jerseyNumber: $0, name: "選手\($0)") }

        var initial = MatchSetupFeature.State(team: team)
        initial.startingLineup = players
        initial.opponentTeamName = "対戦相手"
        initial.formation = .f5_1_3

        let store = TestStore(initialState: initial) {
            MatchSetupFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        store.exhaustivity = .off

        await store.send(.createMatchTapped(recorderId: UUID(), matchCode: "ABCDEF", codeExpiresAt: Date()))

        // 非同期で matchPrepared が届くまで待つ
        await store.receive(\.matchPrepared, timeout: .seconds(2)) { state in
            guard let match = state.setupResult else {
                Issue.record("setupResult が nil")
                return
            }
            #expect(match.serviceOrders.count == 9)
            #expect(match.sets.count == 1)
            #expect(match.sets[0].setNumber == 1)
        }
    }
}
