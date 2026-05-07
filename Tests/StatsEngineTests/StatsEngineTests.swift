import Testing
import Foundation
@testable import Models
@testable import StatsEngine

// MARK: - Fixture

struct StatsTestFixture: Sendable {
    var players: [UUID]
    let opponentJersey = 7
    var match: Match
    var setId: UUID

    init(plays: [Play] = []) {
        self.players = (0..<9).map { _ in UUID() }
        let teamId = UUID()
        let matchId = UUID()
        let setId = UUID()
        self.setId = setId

        let serviceOrders = self.players.enumerated().map {
            ServiceOrderEntry(matchId: matchId, order: $0.offset + 1, startingPlayerId: $0.element)
        }
        let rally = Rally(
            id: UUID(),
            setId: setId,
            rallyNumber: 1,
            startScoreUs: 0, startScoreOpp: 0,
            servingTeam: .own,
            plays: plays
        )
        let set = MatchSet(
            id: setId,
            matchId: matchId,
            setNumber: 1,
            formation: .f5_1_3,
            rallies: [rally]
        )
        self.match = Match(
            id: matchId,
            teamId: teamId,
            recorderId: UUID(),
            matchCode: "ABCDEF",
            matchCodeExpiresAt: Date(),
            date: Date(),
            startTime: Date(),
            opponentTeamName: "対戦相手",
            matchType: .practice,
            serviceOrders: serviceOrders,
            sets: [set]
        )
    }

    func play(team: Team.ServingSide, type: PlayType, eval: Evaluation, player: UUID? = nil, jersey: Int? = nil, receptionQuality: ReceptionQuality? = nil) -> Play {
        Play(
            rallyId: match.sets[0].rallies[0].id,
            sequenceInRally: 0,
            playTeam: team,
            playerId: player,
            opponentJersey: jersey,
            playType: type,
            evaluation: eval,
            receptionQuality: receptionQuality
        )
    }
}

// MARK: - Attack KPIs

@Suite("StatsEngine: attack")
struct AttackTests {
    @Test("0 打数なら全 KPI=0")
    func zero_attempts() {
        let f = StatsTestFixture()
        let engine = StatsEngine()
        let stats = engine.teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(stats.attackAttempts == 0)
        #expect(stats.attackKills == 0)
        #expect(stats.attackKillRate == 0.0)
        #expect(stats.attackEfficiency == 0.0)
    }

    @Test("1打数1決定 → killRate=100, efficiency=100")
    func single_kill() {
        var f = StatsTestFixture()
        let p = f.play(team: .own, type: .attack, eval: .excellent, player: f.players[0])
        f = makeFixture(with: [p], from: f)
        let engine = StatsEngine()
        let s = engine.teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.attackAttempts == 1)
        #expect(s.attackKills == 1)
        #expect(s.attackKillRate == 100.0)
        #expect(s.attackEfficiency == 100.0)
    }

    @Test("1打数1ミス → efficiency=-100")
    func single_error() {
        var f = StatsTestFixture()
        let p = f.play(team: .own, type: .attack, eval: .error, player: f.players[0])
        f = makeFixture(with: [p], from: f)
        let s = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.attackAttempts == 1)
        #expect(s.attackKills == 0)
        #expect(s.attackErrors == 1)
        #expect(s.attackEfficiency == -100.0)
    }

    @Test("4打数1決定1ミス2普通 → killRate=25, efficiency=0")
    func mixed() {
        var f = StatsTestFixture()
        let plays = [
            f.play(team: .own, type: .attack, eval: .excellent, player: f.players[0]),
            f.play(team: .own, type: .attack, eval: .normal, player: f.players[0]),
            f.play(team: .own, type: .attack, eval: .normal, player: f.players[0]),
            f.play(team: .own, type: .attack, eval: .error, player: f.players[1]),
        ]
        f = makeFixture(with: plays, from: f)
        let s = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.attackAttempts == 4)
        #expect(s.attackKills == 1)
        #expect(s.attackErrors == 1)
        #expect(s.attackKillRate == 25.0)
        #expect(s.attackEfficiency == 0.0)
    }

    @Test("相手 attack は own 集計に含まれない")
    func own_only() {
        var f = StatsTestFixture()
        let plays = [
            f.play(team: .own, type: .attack, eval: .excellent, player: f.players[0]),
            f.play(team: .opponent, type: .attack, eval: .excellent, jersey: 11),
        ]
        f = makeFixture(with: plays, from: f)
        let s = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.attackAttempts == 1)

        let opp = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .opponent)
        #expect(opp.attackAttempts == 1)
    }
}

// MARK: - Reception KPIs

@Suite("StatsEngine: reception")
struct ReceptionTests {
    @Test("Aパス3, Bパス1, Cパス1, Dパス1 → A率=50, 返球率=83.3")
    func mixed_passes() {
        var f = StatsTestFixture()
        let plays: [Play] = [
            f.play(team: .own, type: .reception, eval: .normal, player: f.players[0], receptionQuality: .aPass),
            f.play(team: .own, type: .reception, eval: .normal, player: f.players[0], receptionQuality: .aPass),
            f.play(team: .own, type: .reception, eval: .normal, player: f.players[0], receptionQuality: .aPass),
            f.play(team: .own, type: .reception, eval: .normal, player: f.players[0], receptionQuality: .bPass),
            f.play(team: .own, type: .reception, eval: .normal, player: f.players[0], receptionQuality: .cPass),
            f.play(team: .own, type: .reception, eval: .error, player: f.players[0], receptionQuality: .dPass),
        ]
        f = makeFixture(with: plays, from: f)
        let s = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.receptionAttempts == 6)
        #expect(s.receptionAPasses == 3)
        #expect(s.receptionAPassRate == 50.0)
        #expect(abs(s.receptionReturnRate - 83.33333) < 0.01)
    }
}

// MARK: - Serve KPIs

@Suite("StatsEngine: serve")
struct ServeTests {
    @Test("3エース1ミス4普通 → efficiency=25")
    func serve_efficiency() {
        var f = StatsTestFixture()
        let plays = [
            f.play(team: .own, type: .serve, eval: .excellent, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .excellent, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .excellent, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .error, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .normal, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .normal, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .normal, player: f.players[0]),
            f.play(team: .own, type: .serve, eval: .normal, player: f.players[0]),
        ]
        f = makeFixture(with: plays, from: f)
        let s = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.serveAttempts == 8)
        #expect(s.serveAces == 3)
        #expect(s.serveErrors == 1)
        #expect(s.serveEfficiency == 25.0)
    }
}

// MARK: - Block / Dig / Set / Assist

@Suite("StatsEngine: block / dig / set / assist")
struct BlockDigSetTests {
    @Test("ブロック3 (うち決定2)、ディグ4、セット5 (アシスト2)")
    func counts() {
        var f = StatsTestFixture()
        var plays: [Play] = []
        for _ in 0..<3 {
            plays.append(f.play(team: .own, type: .block, eval: .excellent, player: f.players[0]))
        }
        plays.append(f.play(team: .own, type: .block, eval: .normal, player: f.players[0]))
        for _ in 0..<4 {
            plays.append(f.play(team: .own, type: .dig, eval: .normal, player: f.players[1]))
        }
        for _ in 0..<5 {
            var set = f.play(team: .own, type: .set, eval: .normal, player: f.players[2])
            set.isAssist = true
            plays.append(set)
        }
        // assist 数を 2 にしたいので 3 個の isAssist を false に倒す
        for i in (plays.count - 5)..<(plays.count - 2) {
            plays[i].isAssist = false
        }

        f = makeFixture(with: plays, from: f)
        let s = StatsEngine().teamStats(in: f.match, scope: .wholeMatch, side: .own)
        #expect(s.blocks == 4)
        #expect(s.blockKills == 3)
        #expect(s.digs == 4)
        #expect(s.sets == 5)
        #expect(s.assists == 2)
    }
}

// MARK: - Player stats

@Suite("StatsEngine: player stats")
struct PlayerStatsTests {
    @Test("特定 playerId の Play のみ集計")
    func only_target_player() {
        var f = StatsTestFixture()
        let target = f.players[0]
        let other = f.players[1]
        let plays = [
            f.play(team: .own, type: .attack, eval: .excellent, player: target),
            f.play(team: .own, type: .attack, eval: .normal, player: target),
            f.play(team: .own, type: .attack, eval: .excellent, player: other),
        ]
        f = makeFixture(with: plays, from: f)
        let p = StatsEngine().playerStats(playerId: target, in: f.match, scope: .wholeMatch)
        #expect(p.attackAttempts == 2)
        #expect(p.attackKills == 1)
        #expect(p.attackKillRate == 50.0)
    }
}

// MARK: - Consecutive runs

@Suite("StatsEngine: consecutive runs")
struct ConsecutiveRunTests {
    @Test("自軍3連続得点で run が抽出される")
    func three_in_a_row_detected() {
        let f = StatsTestFixture()
        var match = f.match
        match.sets[0].rallies = [
            Rally(setId: f.setId, rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 2, startScoreUs: 1, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 3, startScoreUs: 2, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 4, startScoreUs: 3, startScoreOpp: 0, servingTeam: .own, winner: .opponent),
        ]
        let runs = StatsEngine().consecutiveRuns(in: match.sets[0])
        #expect(runs.count == 1)
        #expect(runs[0].team == .own)
        #expect(runs[0].count == 3)
        #expect(runs[0].startRallyNumber == 1)
        #expect(runs[0].endRallyNumber == 3)
    }

    @Test("2連続のみは閾値未満で除外")
    func two_only_ignored() {
        let f = StatsTestFixture()
        var match = f.match
        match.sets[0].rallies = [
            Rally(setId: f.setId, rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 2, startScoreUs: 1, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 3, startScoreUs: 2, startScoreOpp: 0, servingTeam: .own, winner: .opponent),
        ]
        let runs = StatsEngine().consecutiveRuns(in: match.sets[0])
        #expect(runs.isEmpty)
    }

    @Test("自4連続→相手3連続 → 2 runs")
    func mixed_runs() {
        let f = StatsTestFixture()
        var match = f.match
        match.sets[0].rallies = [
            Rally(setId: f.setId, rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 2, startScoreUs: 1, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 3, startScoreUs: 2, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 4, startScoreUs: 3, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 5, startScoreUs: 4, startScoreOpp: 0, servingTeam: .opponent, winner: .opponent),
            Rally(setId: f.setId, rallyNumber: 6, startScoreUs: 4, startScoreOpp: 1, servingTeam: .opponent, winner: .opponent),
            Rally(setId: f.setId, rallyNumber: 7, startScoreUs: 4, startScoreOpp: 2, servingTeam: .opponent, winner: .opponent),
            Rally(setId: f.setId, rallyNumber: 8, startScoreUs: 4, startScoreOpp: 3, servingTeam: .opponent, winner: .own),
        ]
        let runs = StatsEngine().consecutiveRuns(in: match.sets[0])
        #expect(runs.count == 2)
        #expect(runs[0].team == .own && runs[0].count == 4)
        #expect(runs[1].team == .opponent && runs[1].count == 3)
    }

    @Test("カスタム threshold")
    func custom_threshold() {
        let f = StatsTestFixture()
        var match = f.match
        match.sets[0].rallies = [
            Rally(setId: f.setId, rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own, winner: .own),
            Rally(setId: f.setId, rallyNumber: 2, startScoreUs: 1, startScoreOpp: 0, servingTeam: .own, winner: .own),
        ]
        let runs = StatsEngine().consecutiveRuns(in: match.sets[0], threshold: 2)
        #expect(runs.count == 1)
        #expect(runs[0].count == 2)
    }
}

// MARK: - Scope

@Suite("StatsEngine: scope")
struct ScopeTests {
    @Test("scope=set(2) は set 2 のみ集計")
    func set_scope() {
        let f = StatsTestFixture()
        var match = f.match
        // セット2を追加
        let set2Id = UUID()
        let rally2 = Rally(
            id: UUID(),
            setId: set2Id,
            rallyNumber: 1,
            startScoreUs: 0, startScoreOpp: 0,
            servingTeam: .own,
            plays: [
                Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playerId: f.players[0], playType: .attack, evaluation: .excellent),
                Play(rallyId: UUID(), sequenceInRally: 2, playTeam: .own, playerId: f.players[0], playType: .attack, evaluation: .excellent),
            ]
        )
        let set2 = MatchSet(id: set2Id, matchId: match.id, setNumber: 2, formation: .f5_1_3, rallies: [rally2])
        // セット1にも追加
        match.sets[0].rallies[0].plays = [
            Play(rallyId: match.sets[0].rallies[0].id, sequenceInRally: 1, playTeam: .own, playerId: f.players[0], playType: .attack, evaluation: .excellent),
        ]
        match.sets.append(set2)

        let s2 = StatsEngine().teamStats(in: match, scope: .set(2), side: .own)
        #expect(s2.attackAttempts == 2)

        let s1 = StatsEngine().teamStats(in: match, scope: .set(1), side: .own)
        #expect(s1.attackAttempts == 1)

        let all = StatsEngine().teamStats(in: match, scope: .wholeMatch, side: .own)
        #expect(all.attackAttempts == 3)
    }
}

// MARK: - Course Tendency / Formation (Phase 1.1)

@Suite("StatsEngine: course tendency")
struct CourseTendencyTests {
    @Test("相手 attack course 集計")
    func opp_attack_course() {
        var f = StatsTestFixture()
        let plays = [
            Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .opponent, opponentJersey: 7, playType: .attack, evaluation: .normal, attackCourse: .cross),
            Play(rallyId: UUID(), sequenceInRally: 2, playTeam: .opponent, opponentJersey: 7, playType: .attack, evaluation: .normal, attackCourse: .cross),
            Play(rallyId: UUID(), sequenceInRally: 3, playTeam: .opponent, opponentJersey: 11, playType: .attack, evaluation: .normal, attackCourse: .straight),
        ]
        f = makeFixture(with: plays, from: f)
        let tally = StatsEngine().opponentAttackCourseTally(in: f.match, scope: .wholeMatch)
        #expect(tally[.cross] == 2)
        #expect(tally[.straight] == 1)
    }

    @Test("相手 serve course 集計")
    func opp_serve_course() {
        var f = StatsTestFixture()
        let plays = [
            Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .opponent, opponentJersey: 7, playType: .serve, evaluation: .normal, serveCourse: 1),
            Play(rallyId: UUID(), sequenceInRally: 2, playTeam: .opponent, opponentJersey: 7, playType: .serve, evaluation: .normal, serveCourse: 1),
            Play(rallyId: UUID(), sequenceInRally: 3, playTeam: .opponent, opponentJersey: 7, playType: .serve, evaluation: .normal, serveCourse: 5),
        ]
        f = makeFixture(with: plays, from: f)
        let tally = StatsEngine().opponentServeCourseTally(in: f.match, scope: .wholeMatch)
        #expect(tally[1] == 2)
        #expect(tally[5] == 1)
    }
}

// MARK: - Helpers

private func makeFixture(with plays: [Play], from old: StatsTestFixture) -> StatsTestFixture {
    var f = old
    let setId = f.setId
    let rallyId = f.match.sets[0].rallies[0].id
    f.match.sets[0].rallies[0].plays = plays.enumerated().map { idx, p in
        var copy = p
        copy.rallyId = rallyId
        copy.sequenceInRally = idx + 1
        return copy
    }
    _ = setId  // silence warning
    return f
}

