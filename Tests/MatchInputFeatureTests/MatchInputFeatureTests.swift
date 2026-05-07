import Testing
import Foundation
import ComposableArchitecture
import Dependencies
@testable import Models
@testable import LocalStore
@testable import ServiceOrderEngine
@testable import MatchInputFeature

@MainActor
struct MatchInputTestFixture: Sendable {
    let starters: [UUID]
    let bench: [UUID]
    let match: Match
    let setId: UUID

    init() {
        let starters = (0..<9).map { _ in UUID() }
        let bench = (0..<2).map { _ in UUID() }
        let engine = ServiceOrderEngine()
        var m = Match(
            teamId: UUID(),
            recorderId: UUID(),
            matchCode: "ABCDEF",
            matchCodeExpiresAt: Date(),
            date: Date(),
            startTime: Date(),
            opponentTeamName: "対戦相手",
            matchType: .practice
        )
        let starting = starters.enumerated().map { (order: $0.offset + 1, playerId: $0.element) }
        m = try! engine.initializeForNewSet(match: m, setNumber: 1, formation: .f5_1_3, startingPlayers: starting)
        self.starters = starters
        self.bench = bench
        self.match = m
        self.setId = m.sets[0].id
    }
}

@MainActor
@Suite("MatchInputFeature: mode/team")
struct MatchInputFeatureBasicTests {
    @Test("mode 切替で state 更新")
    func mode_changes() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        await store.send(.modeChanged(.detailed)) {
            $0.inputMode = .detailed
        }
    }

    @Test("teamSwitched で player/jersey ドラフトがクリア")
    func team_switch_clears_drafts() async {
        let f = MatchInputTestFixture()
        var initial = MatchInputFeature.State(match: f.match, currentSetId: f.setId)
        initial.draftSelectedPlayerId = f.starters[0]

        let store = TestStore(initialState: initial) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        await store.send(.teamSwitched(.opponent)) {
            $0.draftSelectedTeam = .opponent
            $0.draftSelectedPlayerId = nil
            $0.draftOpponentJersey = nil
        }
    }
}

@MainActor
@Suite("MatchInputFeature: play commit")
struct MatchInputFeaturePlayTests {
    @Test("PlayType + Player + Evaluation で Play 追加、ドラフトリセット")
    func commit_play() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        store.exhaustivity = .off

        await store.send(.playerSelected(f.starters[0]))
        await store.send(.playTypeSelected(.serve))
        await store.send(.evaluationSelected(.excellent)) { state in
            #expect(state.draftPlayType == nil)
            #expect(state.match.sets[0].rallies.count == 1)
            #expect(state.match.sets[0].rallies[0].plays.count == 1)
            #expect(state.match.sets[0].rallies[0].plays[0].evaluation == .excellent)
            #expect(state.match.sets[0].rallies[0].plays[0].playType == .serve)
            #expect(state.match.sets[0].rallies[0].plays[0].playerId == f.starters[0])
        }
    }

    @Test("PlayType 未選択で evaluation すると errorMessage")
    func no_playtype_error() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        await store.send(.evaluationSelected(.excellent)) {
            $0.errorMessage = "プレー種別を選択してください"
        }
    }

    @Test("自軍プレーで player 未選択 → errorMessage")
    func own_no_player() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        await store.send(.playTypeSelected(.serve)) {
            $0.draftPlayType = .serve
        }
        await store.send(.evaluationSelected(.excellent)) {
            $0.errorMessage = "自軍プレーは選手を選択してください"
        }
    }
}

@MainActor
@Suite("MatchInputFeature: undo")
struct MatchInputFeatureUndoTests {
    @Test("Play 確定 → undo で 元に戻る")
    func undo_after_play() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        store.exhaustivity = .off

        await store.send(.playerSelected(f.starters[0]))
        await store.send(.playTypeSelected(.serve))
        await store.send(.evaluationSelected(.excellent)) { state in
            #expect(state.match.sets[0].rallies.count == 1)
        }

        await store.send(.undoTapped) { state in
            #expect(state.match.sets[0].rallies.count == 0)
        }
    }

    @Test("最大5ステップ: 6回 undo しても 5件分しか戻らない")
    func undo_limited_to_5() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        store.exhaustivity = .off

        // 6回 Play 確定 (snapshot 5件で打ち切り)
        for _ in 0..<6 {
            await store.send(.playerSelected(f.starters[0]))
            await store.send(.playTypeSelected(.attack))
            await store.send(.evaluationSelected(.normal))
        }
        // この時点で plays は 6件, history は 5件
        await store.send(.undoTapped)
        await store.send(.undoTapped)
        await store.send(.undoTapped)
        await store.send(.undoTapped)
        await store.send(.undoTapped)
        // 5回 undo すると履歴は空。6回目は no-op
        await store.send(.undoTapped) { state in
            // 履歴が空なので state は変化なし。plays は最初の Play (6個目をundoで戻したあとさらに5回戻った状態)
            // つまり 1件の Play が残っている (最初の Play は snapshot に積まれていなかった)
            #expect(state.match.sets[0].rallies[0].plays.count == 1)
        }
    }
}

@MainActor
@Suite("MatchInputFeature: timeout")
struct MatchInputFeatureTimeoutTests {
    @Test("自軍 TO 2回まで OK、3回目はエラー")
    func own_timeout_limit() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        store.exhaustivity = .off

        await store.send(.timeoutRequested(.own)) { state in
            #expect(state.match.sets[0].timeouts.count == 1)
        }
        await store.send(.timeoutRequested(.own)) { state in
            #expect(state.match.sets[0].timeouts.count == 2)
        }
        await store.send(.timeoutRequested(.own)) { state in
            #expect(state.errorMessage?.contains("2回") == true)
            #expect(state.match.sets[0].timeouts.count == 2)  // 3回目は積まれない
        }
    }
}

@MainActor
@Suite("MatchInputFeature: rally end")
struct MatchInputFeatureRallyEndTests {
    @Test("自軍得点で rally.winner=.own、ServiceOrderEngine の advance が反映")
    func rally_end_own() async {
        let f = MatchInputTestFixture()
        let store = TestStore(initialState: MatchInputFeature.State(match: f.match, currentSetId: f.setId)) {
            MatchInputFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
        }
        store.exhaustivity = .off

        // 自軍 サーブを記録
        await store.send(.playerSelected(f.starters[0]))
        await store.send(.playTypeSelected(.serve))
        await store.send(.evaluationSelected(.excellent))

        await store.send(.rallyEndTapped(winner: .own)) { state in
            let rally = state.match.sets[0].rallies[0]
            #expect(rally.winner == .own)
            #expect(rally.endedAt != nil)
            #expect(state.match.sets[0].lastServingTeam == .own)
        }
    }
}
