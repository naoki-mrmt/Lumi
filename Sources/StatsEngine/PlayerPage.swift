// PlayerPage — 選手個人マイページの集計 (Phase 2.2)

import Foundation
import Models

public struct PlayerPageData: Equatable, Sendable {
    public let playerId: UUID
    public let careerStats: PlayerStats
    public let recentMatches: [PlayerMatchRecord]

    public struct PlayerMatchRecord: Equatable, Sendable {
        public let matchId: UUID
        public let date: Date
        public let opponentName: String
        public let stats: PlayerStats
    }
}

public extension StatsEngine {
    /// 選手個人ページ用データ (キャリア累計 + 直近試合別)
    func playerPage(playerId: UUID, in matches: [Match], recentLimit: Int = 5) -> PlayerPageData {
        var aggregate = PlayerStats(
            playerId: playerId,
            attackAttempts: 0, attackKills: 0,
            attackKillRate: 0, attackEfficiency: 0,
            receptionAttempts: 0, receptionAPassRate: 0,
            serveAttempts: 0, serveAces: 0,
            assists: 0, blockKills: 0, digs: 0
        )
        var records: [PlayerPageData.PlayerMatchRecord] = []
        for m in matches {
            let s = playerStats(playerId: playerId, in: m, scope: .wholeMatch)
            if s.attackAttempts > 0 || s.serveAttempts > 0 || s.receptionAttempts > 0 {
                records.append(PlayerPageData.PlayerMatchRecord(
                    matchId: m.id, date: m.date, opponentName: m.opponentTeamName, stats: s
                ))
                aggregate = mergePlayerStats(aggregate, s)
            }
        }
        let recent = Array(records.sorted(by: { $0.date > $1.date }).prefix(recentLimit))
        return PlayerPageData(
            playerId: playerId,
            careerStats: aggregate,
            recentMatches: recent
        )
    }

    private func mergePlayerStats(_ a: PlayerStats, _ b: PlayerStats) -> PlayerStats {
        let attacks = a.attackAttempts + b.attackAttempts
        let kills = a.attackKills + b.attackKills
        return PlayerStats(
            playerId: a.playerId,
            attackAttempts: attacks,
            attackKills: kills,
            attackKillRate: attacks > 0 ? Double(kills) / Double(attacks) * 100 : 0,
            attackEfficiency: attacks > 0 ? Double(kills - 0) / Double(attacks) * 100 : 0,
            receptionAttempts: a.receptionAttempts + b.receptionAttempts,
            receptionAPassRate: 0,  // 累計時は単純計算しない (re-aggregate が必要)
            serveAttempts: a.serveAttempts + b.serveAttempts,
            serveAces: a.serveAces + b.serveAces,
            assists: a.assists + b.assists,
            blockKills: a.blockKills + b.blockKills,
            digs: a.digs + b.digs
        )
    }
}
