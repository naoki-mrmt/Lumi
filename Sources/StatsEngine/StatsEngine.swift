// StatsEngine — KPI計算ロジック (純粋関数)
//
// docs/03_DOMAIN_MODEL.md 2.3 集計指標の計算式 に厳密準拠
//   attack_kill_rate = excellent / attempts * 100
//   attack_efficiency = (excellent - error) / attempts * 100
//   reception_a_rate = aPass / attempts * 100
//   reception_return_rate = (aPass + bPass + cPass) / attempts * 100
//   serve_efficiency = (aces - errors) / attempts * 100
//
// attempts == 0 のとき割合は 0.0 (NaN ではなく)。

import Foundation
import Models

public struct StatsEngine: Sendable {
    public init() {}

    // MARK: - Team Stats

    public func teamStats(in match: Match, scope: StatsScope, side: Team.ServingSide) -> TeamStats {
        let plays = filteredPlays(in: match, scope: scope).filter { $0.playTeam == side }
        return computeTeamStats(plays: plays)
    }

    // MARK: - Player Stats

    public func playerStats(playerId: UUID, in match: Match, scope: StatsScope) -> PlayerStats {
        let plays = filteredPlays(in: match, scope: scope)
            .filter { $0.playTeam == .own && $0.playerId == playerId }
        let team = computeTeamStats(plays: plays)
        return PlayerStats(
            playerId: playerId,
            attackAttempts: team.attackAttempts,
            attackKills: team.attackKills,
            attackKillRate: team.attackKillRate,
            attackEfficiency: team.attackEfficiency,
            receptionAttempts: team.receptionAttempts,
            receptionAPassRate: team.receptionAPassRate,
            serveAttempts: team.serveAttempts,
            serveAces: team.serveAces,
            assists: team.assists,
            blockKills: team.blockKills,
            digs: team.digs
        )
    }

    // MARK: - Course Tendency (Phase 1.1)

    /// 相手チームのアタックコース傾向 (件数)
    public func opponentAttackCourseTally(in match: Match, scope: StatsScope) -> [AttackCourse: Int] {
        let plays = filteredPlays(in: match, scope: scope)
            .filter { $0.playTeam == .opponent && $0.playType == .attack }
        return Dictionary(grouping: plays.compactMap(\.attackCourse), by: { $0 }).mapValues(\.count)
    }

    /// 相手チームのサーブコース (1..9 ゾーン) 傾向
    public func opponentServeCourseTally(in match: Match, scope: StatsScope) -> [Int: Int] {
        let plays = filteredPlays(in: match, scope: scope)
            .filter { $0.playTeam == .opponent && $0.playType == .serve }
        return Dictionary(grouping: plays.compactMap(\.serveCourse), by: { $0 }).mapValues(\.count)
    }

    /// フォーメーション別集計 (チーム単位)
    public func teamStatsByFormation(in match: Match, side: Team.ServingSide) -> [Formation: TeamStats] {
        var out: [Formation: TeamStats] = [:]
        for set in match.sets {
            let stats = teamStats(in: match, scope: .set(set.setNumber), side: side)
            out[set.formation, default: .empty] = mergeStats(out[set.formation] ?? .empty, stats)
        }
        return out
    }

    private func mergeStats(_ a: TeamStats, _ b: TeamStats) -> TeamStats {
        let attacks = a.attackAttempts + b.attackAttempts
        let kills = a.attackKills + b.attackKills
        let errs = a.attackErrors + b.attackErrors
        let recs = a.receptionAttempts + b.receptionAttempts
        let aPasses = a.receptionAPasses + b.receptionAPasses
        let bPasses = a.receptionBPasses + b.receptionBPasses
        let cPasses = a.receptionCPasses + b.receptionCPasses
        let dPasses = a.receptionDPasses + b.receptionDPasses
        let serves = a.serveAttempts + b.serveAttempts
        let aces = a.serveAces + b.serveAces
        let serveErrs = a.serveErrors + b.serveErrors
        return TeamStats(
            attackAttempts: attacks,
            attackKills: kills,
            attackErrors: errs,
            attackKillRate: pct(kills, attacks),
            attackEfficiency: pct(kills - errs, attacks),
            receptionAttempts: recs,
            receptionAPasses: aPasses,
            receptionBPasses: bPasses,
            receptionCPasses: cPasses,
            receptionDPasses: dPasses,
            receptionAPassRate: pct(aPasses, recs),
            receptionReturnRate: pct(aPasses + bPasses + cPasses, recs),
            serveAttempts: serves,
            serveAces: aces,
            serveErrors: serveErrs,
            serveEfficiency: pct(aces - serveErrs, serves),
            blocks: a.blocks + b.blocks,
            blockKills: a.blockKills + b.blockKills,
            digs: a.digs + b.digs,
            sets: a.sets + b.sets,
            assists: a.assists + b.assists
        )
    }

    private func pct(_ n: Int, _ d: Int) -> Double {
        d > 0 ? Double(n) / Double(d) * 100 : 0
    }

    // MARK: - Consecutive Runs

    public func consecutiveRuns(in set: MatchSet, threshold: Int = 3) -> [ConsecutiveRun] {
        let endedRallies = set.rallies
            .filter { $0.winner != nil }
            .sorted { $0.rallyNumber < $1.rallyNumber }

        var runs: [ConsecutiveRun] = []
        var currentTeam: Team.ServingSide?
        var currentStart: Int = 0
        var currentEnd: Int = 0
        var currentCount: Int = 0

        for rally in endedRallies {
            guard let winner = rally.winner else { continue }
            if winner == currentTeam {
                currentCount += 1
                currentEnd = rally.rallyNumber
            } else {
                if let team = currentTeam, currentCount >= threshold {
                    runs.append(ConsecutiveRun(
                        team: team,
                        count: currentCount,
                        startRallyNumber: currentStart,
                        endRallyNumber: currentEnd
                    ))
                }
                currentTeam = winner
                currentStart = rally.rallyNumber
                currentEnd = rally.rallyNumber
                currentCount = 1
            }
        }
        if let team = currentTeam, currentCount >= threshold {
            runs.append(ConsecutiveRun(
                team: team,
                count: currentCount,
                startRallyNumber: currentStart,
                endRallyNumber: currentEnd
            ))
        }
        return runs
    }

    // MARK: - Internal

    private func filteredPlays(in match: Match, scope: StatsScope) -> [Play] {
        let sets: [MatchSet]
        switch scope {
        case .wholeMatch:
            sets = match.sets
        case let .set(number):
            sets = match.sets.filter { $0.setNumber == number }
        case let .formation(formation):
            sets = match.sets.filter { $0.formation == formation }
        }
        return sets.flatMap { $0.rallies.flatMap { $0.plays } }
    }

    private func computeTeamStats(plays: [Play]) -> TeamStats {
        // Attack
        let attacks = plays.filter { $0.playType == .attack }
        let attackKills = attacks.filter { $0.evaluation == .excellent }.count
        let attackErrors = attacks.filter { $0.evaluation == .error }.count

        // Reception
        let receptions = plays.filter { $0.playType == .reception }
        let aPasses = receptions.filter { $0.receptionQuality == .aPass }.count
        let bPasses = receptions.filter { $0.receptionQuality == .bPass }.count
        let cPasses = receptions.filter { $0.receptionQuality == .cPass }.count
        let dPasses = receptions.filter { $0.receptionQuality == .dPass }.count

        // Serve
        let serves = plays.filter { $0.playType == .serve }
        let aces = serves.filter { $0.evaluation == .excellent }.count
        let serveErrors = serves.filter { $0.evaluation == .error }.count

        // Block / Dig / Set
        let blocks = plays.filter { $0.playType == .block }
        let blockKills = blocks.filter { $0.evaluation == .excellent }.count
        let digs = plays.filter { $0.playType == .dig }.count
        let sets = plays.filter { $0.playType == .set }
        let assists = sets.filter(\.isAssist).count

        return TeamStats(
            attackAttempts: attacks.count,
            attackKills: attackKills,
            attackErrors: attackErrors,
            attackKillRate: percentage(numerator: attackKills, denominator: attacks.count),
            attackEfficiency: percentage(numerator: attackKills - attackErrors, denominator: attacks.count),
            receptionAttempts: receptions.count,
            receptionAPasses: aPasses,
            receptionBPasses: bPasses,
            receptionCPasses: cPasses,
            receptionDPasses: dPasses,
            receptionAPassRate: percentage(numerator: aPasses, denominator: receptions.count),
            receptionReturnRate: percentage(numerator: aPasses + bPasses + cPasses, denominator: receptions.count),
            serveAttempts: serves.count,
            serveAces: aces,
            serveErrors: serveErrors,
            serveEfficiency: percentage(numerator: aces - serveErrors, denominator: serves.count),
            blocks: blocks.count,
            blockKills: blockKills,
            digs: digs,
            sets: sets.count,
            assists: assists
        )
    }

    private func percentage(numerator: Int, denominator: Int) -> Double {
        guard denominator > 0 else { return 0.0 }
        return Double(numerator) / Double(denominator) * 100.0
    }
}

// MARK: - Types

public enum StatsScope: Equatable, Hashable, Sendable {
    case wholeMatch
    case set(Int)
    case formation(Formation)
}

public struct TeamStats: Equatable, Sendable {
    public var attackAttempts: Int
    public var attackKills: Int
    public var attackErrors: Int
    public var attackKillRate: Double
    public var attackEfficiency: Double

    public var receptionAttempts: Int
    public var receptionAPasses: Int
    public var receptionBPasses: Int
    public var receptionCPasses: Int
    public var receptionDPasses: Int
    public var receptionAPassRate: Double
    public var receptionReturnRate: Double

    public var serveAttempts: Int
    public var serveAces: Int
    public var serveErrors: Int
    public var serveEfficiency: Double

    public var blocks: Int
    public var blockKills: Int
    public var digs: Int
    public var sets: Int
    public var assists: Int

    public static let empty = TeamStats(
        attackAttempts: 0, attackKills: 0, attackErrors: 0,
        attackKillRate: 0, attackEfficiency: 0,
        receptionAttempts: 0, receptionAPasses: 0, receptionBPasses: 0,
        receptionCPasses: 0, receptionDPasses: 0,
        receptionAPassRate: 0, receptionReturnRate: 0,
        serveAttempts: 0, serveAces: 0, serveErrors: 0, serveEfficiency: 0,
        blocks: 0, blockKills: 0, digs: 0, sets: 0, assists: 0
    )
}

public struct PlayerStats: Equatable, Sendable {
    public var playerId: UUID
    public var attackAttempts: Int
    public var attackKills: Int
    public var attackKillRate: Double
    public var attackEfficiency: Double
    public var receptionAttempts: Int
    public var receptionAPassRate: Double
    public var serveAttempts: Int
    public var serveAces: Int
    public var assists: Int
    public var blockKills: Int
    public var digs: Int
}

public struct ConsecutiveRun: Equatable, Hashable, Sendable {
    public let team: Team.ServingSide
    public let count: Int
    public let startRallyNumber: Int
    public let endRallyNumber: Int
}
