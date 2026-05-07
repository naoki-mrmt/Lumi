// SeasonStats — 複数試合横断の集計 (Phase 2.0)

import Foundation
import Models

public struct SeasonStats: Equatable, Sendable {
    public let matchCount: Int
    public let winCount: Int
    public let lossCount: Int
    public let aggregate: TeamStats   // 全試合の合計
    public let perMatch: [MatchSummary]

    public struct MatchSummary: Equatable, Hashable, Sendable {
        public let matchId: UUID
        public let opponentTeamName: String
        public let date: Date
        public let ourSetsWon: Int
        public let opponentSetsWon: Int
        public let result: Result

        public enum Result: String, Sendable {
            case win, loss, draw, unfinished
        }
    }
}

public extension StatsEngine {
    /// シーズン累計集計 (複数試合)
    func seasonStats(matches: [Match]) -> SeasonStats {
        var aggregate: TeamStats = .empty
        var summaries: [SeasonStats.MatchSummary] = []
        var winCount = 0
        var lossCount = 0

        for match in matches {
            let ts = teamStats(in: match, scope: .wholeMatch, side: .own)
            aggregate = mergeStatsAccessible(aggregate, ts)

            let ourSetsWon = match.sets.filter { ($0.ourScoreFinal ?? 0) > ($0.opponentScoreFinal ?? 0) }.count
            let oppSetsWon = match.sets.filter { ($0.ourScoreFinal ?? 0) < ($0.opponentScoreFinal ?? 0) }.count
            let result: SeasonStats.MatchSummary.Result
            if match.status != .finished {
                result = .unfinished
            } else if ourSetsWon > oppSetsWon {
                result = .win; winCount += 1
            } else if ourSetsWon < oppSetsWon {
                result = .loss; lossCount += 1
            } else {
                result = .draw
            }
            summaries.append(.init(
                matchId: match.id,
                opponentTeamName: match.opponentTeamName,
                date: match.date,
                ourSetsWon: ourSetsWon,
                opponentSetsWon: oppSetsWon,
                result: result
            ))
        }

        return SeasonStats(
            matchCount: matches.count,
            winCount: winCount,
            lossCount: lossCount,
            aggregate: aggregate,
            perMatch: summaries
        )
    }

    /// 公開ラッパー (private mergeStats を再露出)
    func mergeStatsAccessible(_ a: TeamStats, _ b: TeamStats) -> TeamStats {
        // 内部 mergeStats と同じ計算をインライン化
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
            attackKillRate: pctPub(kills, attacks),
            attackEfficiency: pctPub(kills - errs, attacks),
            receptionAttempts: recs,
            receptionAPasses: aPasses,
            receptionBPasses: bPasses,
            receptionCPasses: cPasses,
            receptionDPasses: dPasses,
            receptionAPassRate: pctPub(aPasses, recs),
            receptionReturnRate: pctPub(aPasses + bPasses + cPasses, recs),
            serveAttempts: serves,
            serveAces: aces,
            serveErrors: serveErrs,
            serveEfficiency: pctPub(aces - serveErrs, serves),
            blocks: a.blocks + b.blocks,
            blockKills: a.blockKills + b.blockKills,
            digs: a.digs + b.digs,
            sets: a.sets + b.sets,
            assists: a.assists + b.assists
        )
    }

    private func pctPub(_ n: Int, _ d: Int) -> Double {
        d > 0 ? Double(n) / Double(d) * 100 : 0
    }
}
