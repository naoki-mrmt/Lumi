import Testing
import Foundation
@testable import Models
@testable import ServiceOrderEngine

// MARK: - Test Helpers

struct ServiceOrderTestFixture: Sendable {
    let matchId: UUID
    let players: [UUID]   // 11人 (スタメン9 + 控え2)
    let starters: [UUID]  // 9人 (order=1..9)
    let bench: [UUID]     // 2人

    init() {
        let mid = UUID()
        let all = (0..<11).map { _ in UUID() }
        self.matchId = mid
        self.players = all
        self.starters = Array(all.prefix(9))
        self.bench = Array(all.suffix(2))
    }

    func startingTuples() -> [(order: Int, playerId: UUID)] {
        zip(1...9, starters).map { (order: $0.0, playerId: $0.1) }
    }

    func makeMatch() -> Match {
        Match(
            id: matchId,
            teamId: UUID(),
            recorderId: UUID(),
            matchCode: "ABC123",
            matchCodeExpiresAt: Date().addingTimeInterval(3600),
            date: Date(),
            startTime: Date(),
            opponentTeamName: "対戦相手",
            matchType: .practice
        )
    }
}

// MARK: - 初期化（initializeForNewSet）

@Suite("ServiceOrderEngine: initializeForNewSet")
struct InitializeNewSetTests {
    @Test("セット1 初期化: ServiceOrderEntry が9件生成、order=1..9 すべて埋まる")
    func set1_init() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = f.makeMatch()

        let updated = try engine.initializeForNewSet(
            match: match,
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        #expect(updated.serviceOrders.count == 9)
        #expect(Set(updated.serviceOrders.map(\.order)) == Set(1...9))
        #expect(updated.sets.count == 1)
        #expect(updated.sets[0].setNumber == 1)
        #expect(updated.sets[0].formation == .f5_1_3)

        // currentPlayerId == startingPlayerId
        for entry in updated.serviceOrders {
            #expect(entry.currentPlayerId == entry.startingPlayerId)
        }
    }

    @Test("セット1 初期化: order=1 が初手サーバー (currentServer)")
    func set1_currentServer() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()

        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        let server = engine.currentServer(in: match, set: match.sets[0])
        #expect(server?.order == 1)
        #expect(server?.currentPlayerId == f.starters[0])
    }

    @Test("startingPlayers が9人未満ならエラー")
    func set1_invalid_count() {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()

        let invalid = Array(f.startingTuples().prefix(8))
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.initializeForNewSet(
                match: f.makeMatch(),
                setNumber: 1,
                formation: .f5_1_3,
                startingPlayers: invalid
            )
        }
    }

    @Test("startingPlayers の playerId 重複ならエラー")
    func set1_duplicate_player() {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()

        var tuples = f.startingTuples()
        tuples[1] = (order: 2, playerId: f.starters[0])  // duplicate
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.initializeForNewSet(
                match: f.makeMatch(),
                setNumber: 1,
                formation: .f5_1_3,
                startingPlayers: tuples
            )
        }
    }

    @Test("startingPlayers の order が 1..9 を網羅しないとエラー")
    func set1_invalid_orders() {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()

        var tuples = f.startingTuples()
        tuples[0] = (order: 10, playerId: tuples[0].playerId)
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.initializeForNewSet(
                match: f.makeMatch(),
                setNumber: 1,
                formation: .f5_1_3,
                startingPlayers: tuples
            )
        }
    }
}

// MARK: - ラリー後更新（advance）

@Suite("ServiceOrderEngine: advance after rally")
struct AdvanceAfterRallyTests {
    @Test("自軍サーブ→自軍勝利: 同じサーバー継続 (lastOwnServingOrder=1, lastServingTeam=own)")
    func own_serve_own_win() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()

        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        let set = match.sets[0]
        let rally = Rally(
            setId: set.id,
            rallyNumber: 1,
            startScoreUs: 0,
            startScoreOpp: 0,
            servingTeam: .own,
            servingPlayerId: f.starters[0],
            winner: .own
        )

        let updatedSet = engine.advance(after: rally, in: match, set: set)
        #expect(updatedSet.lastOwnServingOrder == 1)
        #expect(updatedSet.lastServingTeam == .own)
    }

    @Test("自軍サーブ→相手勝利: サイドアウト、lastServingTeam=opponent")
    func own_serve_opp_win() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        let set = match.sets[0]
        let rally = Rally(
            setId: set.id,
            rallyNumber: 1,
            startScoreUs: 0,
            startScoreOpp: 0,
            servingTeam: .own,
            servingPlayerId: f.starters[0],
            winner: .opponent
        )

        let updatedSet = engine.advance(after: rally, in: match, set: set)
        #expect(updatedSet.lastOwnServingOrder == 1)
        #expect(updatedSet.lastServingTeam == .opponent)
    }

    @Test("相手サーブ→自軍勝利: 自軍にサーブ権、lastOwnServingOrder=nil のとき次は order=1")
    func opp_serve_own_win_first_time() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        // セット1 だが相手から始まったケース: lastOwnServingOrder = nil から始める
        match.sets[0].lastServingTeam = .opponent

        let rally = Rally(
            setId: match.sets[0].id,
            rallyNumber: 1,
            startScoreUs: 0,
            startScoreOpp: 0,
            servingTeam: .opponent,
            opponentServingJersey: 1,
            winner: .own
        )

        let updatedSet = engine.advance(after: rally, in: match, set: match.sets[0])
        #expect(updatedSet.lastServingTeam == .own)
        // 自軍が初めてサーブ権を得た時点では「次に打つ」サーバーは order=1
        let nextServer = engine.currentServer(in: match, set: updatedSet)
        #expect(nextServer?.order == 1)
    }

    @Test("自軍が連続2得点後にサイドアウト→相手1点→自軍復帰: 次は order=2")
    func own_serve_then_sideout_then_recover() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        var set = match.sets[0]

        // r1: 自軍 order=1 サーブ→自軍勝利
        set = engine.advance(after: Rally(
            setId: set.id, rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0,
            servingTeam: .own, servingPlayerId: f.starters[0], winner: .own
        ), in: match, set: set)
        // r2: 自軍 order=1 サーブ→自軍勝利 (連続)
        set = engine.advance(after: Rally(
            setId: set.id, rallyNumber: 2, startScoreUs: 1, startScoreOpp: 0,
            servingTeam: .own, servingPlayerId: f.starters[0], winner: .own
        ), in: match, set: set)
        // r3: 自軍 order=1 サーブ→相手勝利 (サイドアウト)
        set = engine.advance(after: Rally(
            setId: set.id, rallyNumber: 3, startScoreUs: 2, startScoreOpp: 0,
            servingTeam: .own, servingPlayerId: f.starters[0], winner: .opponent
        ), in: match, set: set)
        #expect(set.lastServingTeam == .opponent)
        #expect(set.lastOwnServingOrder == 1)

        // r4: 相手サーブ→自軍勝利 (自軍にサーブ権戻る)
        set = engine.advance(after: Rally(
            setId: set.id, rallyNumber: 4, startScoreUs: 2, startScoreOpp: 1,
            servingTeam: .opponent, opponentServingJersey: 5, winner: .own
        ), in: match, set: set)

        #expect(set.lastServingTeam == .own)

        var matchUpdated = match
        matchUpdated.sets[0] = set
        let server = engine.currentServer(in: matchUpdated, set: set)
        #expect(server?.order == 2)  // order=1 の次
    }
}

// MARK: - セット間引継ぎ（initializeForNewSet, setNumber > 1）

@Suite("ServiceOrderEngine: set transition")
struct SetTransitionTests {
    @Test("セット1終了時 lastOwnServingOrder=3, lastServingTeam=.own → セット2 初手は order=4")
    func set2_start_after_own_serving() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        match.sets[0].lastOwnServingOrder = 3
        match.sets[0].lastServingTeam = .own
        match.sets[0].endedAt = Date()
        match.sets[0].ourScoreFinal = 21
        match.sets[0].opponentScoreFinal = 18

        let updated = try engine.initializeForNewSet(
            match: match,
            setNumber: 2,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        #expect(updated.sets.count == 2)
        let server = engine.currentServer(in: updated, set: updated.sets[1])
        #expect(server?.order == 4)
    }

    @Test("セット1 自軍 lastOwnServingOrder=9 → セット2 初手は order=1 (ラップ)")
    func set2_start_wraps() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        match.sets[0].lastOwnServingOrder = 9
        match.sets[0].lastServingTeam = .own
        match.sets[0].endedAt = Date()

        let updated = try engine.initializeForNewSet(
            match: match,
            setNumber: 2,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        let server = engine.currentServer(in: updated, set: updated.sets[1])
        #expect(server?.order == 1)
    }

    @Test("セット1 相手最終サーブ → セット2 初手は lastOwnServingOrder の次")
    func set2_start_after_opponent_serving() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        // 自軍最終サーブが order=5、その後相手にサイドアウトで負けたケース
        match.sets[0].lastOwnServingOrder = 5
        match.sets[0].lastServingTeam = .opponent
        match.sets[0].endedAt = Date()

        let updated = try engine.initializeForNewSet(
            match: match,
            setNumber: 2,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )
        let server = engine.currentServer(in: updated, set: updated.sets[1])
        #expect(server?.order == 6)
    }

    @Test("setNumber=2 で前セット未終了 (endedAt == nil) ならエラー")
    func set2_previous_not_finished() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        #expect(throws: ServiceOrderError.self) {
            _ = try engine.initializeForNewSet(
                match: match,
                setNumber: 2,
                formation: .f5_1_3,
                startingPlayers: f.startingTuples()
            )
        }
    }
}

// MARK: - 選手交代（substitute）

@Suite("ServiceOrderEngine: substitute")
struct SubstituteTests {
    @Test("選手交代1人: currentPlayerId 更新、startingPlayerId は不変、Substitution 1件追加")
    func single_substitution() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        let setId = match.sets[0].id
        let updated = try engine.substitute(
            in: match,
            setId: setId,
            substitutions: [(playerOut: f.starters[2], playerIn: f.bench[0])],
            atOurScore: 5,
            atOpponentScore: 4,
            timestamp: Date()
        )

        let order3 = updated.serviceOrders.first { $0.order == 3 }!
        #expect(order3.startingPlayerId == f.starters[2])
        #expect(order3.currentPlayerId == f.bench[0])
        #expect(updated.sets[0].substitutions.count == 1)
        #expect(updated.sets[0].substitutions[0].substitutionCountInSet == 1)
    }

    @Test("1回4人交代: tooManyPlayersAtOnce エラー")
    func four_at_once() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        // 4人交代 (max 3)
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.substitute(
                in: match,
                setId: match.sets[0].id,
                substitutions: [
                    (f.starters[0], f.bench[0]),
                    (f.starters[1], f.bench[1]),
                    (f.starters[2], UUID()),
                    (f.starters[3], UUID())
                ],
                atOurScore: 0,
                atOpponentScore: 0,
                timestamp: Date()
            )
        }
    }

    @Test("セット5回目交代: substitutionLimitExceeded")
    func fifth_substitution() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        // 4回交代を実施
        for i in 0..<4 {
            match = try engine.substitute(
                in: match,
                setId: match.sets[0].id,
                substitutions: [(f.starters[i], UUID())],
                atOurScore: i, atOpponentScore: 0, timestamp: Date()
            )
        }
        #expect(match.sets[0].substitutions.count == 4)

        // 5回目 → エラー
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.substitute(
                in: match,
                setId: match.sets[0].id,
                substitutions: [(f.starters[4], UUID())],
                atOurScore: 5, atOpponentScore: 0, timestamp: Date()
            )
        }
    }

    @Test("不在選手の交代: playerNotInOrder エラー")
    func unknown_player_out() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        let match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        let unknown = UUID()
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.substitute(
                in: match,
                setId: match.sets[0].id,
                substitutions: [(unknown, f.bench[0])],
                atOurScore: 0, atOpponentScore: 0, timestamp: Date()
            )
        }
    }
}

// MARK: - 再交代制限（canSubstituteAgain）

@Suite("ServiceOrderEngine: re-substitution")
struct ResubstitutionTests {
    @Test("先発→交代→先発の再交代 OK")
    func starter_to_bench_to_starter_ok() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        // 先発 starters[2] → 控え bench[0]
        match = try engine.substitute(
            in: match, setId: match.sets[0].id,
            substitutions: [(f.starters[2], f.bench[0])],
            atOurScore: 0, atOpponentScore: 0, timestamp: Date()
        )
        // canSubstituteAgain (先発に戻す方向): true
        #expect(engine.canSubstituteAgain(in: match, setId: match.sets[0].id, playerId: f.starters[2]))

        // 控え→先発に戻す
        match = try engine.substitute(
            in: match, setId: match.sets[0].id,
            substitutions: [(f.bench[0], f.starters[2])],
            atOurScore: 0, atOpponentScore: 0, timestamp: Date()
        )

        let order3 = match.serviceOrders.first { $0.order == 3 }!
        #expect(order3.currentPlayerId == f.starters[2])
        #expect(match.sets[0].substitutions.count == 2)
    }

    @Test("3回目の交代 (同じ ServiceOrderEntry): alreadyResubstituted エラー")
    func third_swap_on_same_order_fails() throws {
        let f = ServiceOrderTestFixture()
        let engine = ServiceOrderEngine()
        var match = try engine.initializeForNewSet(
            match: f.makeMatch(),
            setNumber: 1,
            formation: .f5_1_3,
            startingPlayers: f.startingTuples()
        )

        match = try engine.substitute(
            in: match, setId: match.sets[0].id,
            substitutions: [(f.starters[2], f.bench[0])],
            atOurScore: 0, atOpponentScore: 0, timestamp: Date()
        )
        match = try engine.substitute(
            in: match, setId: match.sets[0].id,
            substitutions: [(f.bench[0], f.starters[2])],
            atOurScore: 0, atOpponentScore: 0, timestamp: Date()
        )
        // 3回目 (同じ order=3) → エラー
        #expect(throws: ServiceOrderError.self) {
            _ = try engine.substitute(
                in: match, setId: match.sets[0].id,
                substitutions: [(f.starters[2], f.bench[1])],
                atOurScore: 0, atOpponentScore: 0, timestamp: Date()
            )
        }
    }
}
