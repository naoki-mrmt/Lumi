// CSVExporter — 選手別集計 / 全プレーログを CSV 文字列にする (純粋関数)

import Foundation
import Models
import StatsEngine

public enum CSVExporter {

    // MARK: - Player Stats CSV

    public static func playerStatsCSV(match: Match) -> String {
        let header = [
            "player_id", "attack_attempts", "attack_kills", "kill_rate", "efficiency",
            "reception_attempts", "a_pass_rate", "serve_attempts", "serve_aces",
            "assists", "block_kills", "digs"
        ].joined(separator: ",")

        let engine = StatsEngine()
        let starters = match.serviceOrders.sorted(by: { $0.order < $1.order }).map(\.startingPlayerId)
        let lines: [String] = starters.map { pid in
            let s = engine.playerStats(playerId: pid, in: match, scope: .wholeMatch)
            return [
                pid.uuidString,
                String(s.attackAttempts),
                String(s.attackKills),
                String(format: "%.1f", s.attackKillRate),
                String(format: "%.1f", s.attackEfficiency),
                String(s.receptionAttempts),
                String(format: "%.1f", s.receptionAPassRate),
                String(s.serveAttempts),
                String(s.serveAces),
                String(s.assists),
                String(s.blockKills),
                String(s.digs)
            ].joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n") + "\n"
    }

    // MARK: - All Plays Log CSV

    public static func playLogCSV(match: Match) -> String {
        let header = [
            "set_number", "rally_number", "sequence", "team",
            "player_id", "opponent_jersey", "play_type", "evaluation",
            "serve_type", "reception_quality", "attack_course", "is_assist", "timestamp"
        ].joined(separator: ",")

        let isoFormatter = ISO8601DateFormatter()

        var rows: [String] = []
        for set in match.sets.sorted(by: { $0.setNumber < $1.setNumber }) {
            for rally in set.rallies.sorted(by: { $0.rallyNumber < $1.rallyNumber }) {
                for play in rally.plays.sorted(by: { $0.sequenceInRally < $1.sequenceInRally }) {
                    rows.append([
                        String(set.setNumber),
                        String(rally.rallyNumber),
                        String(play.sequenceInRally),
                        play.playTeam.rawValue,
                        play.playerId?.uuidString ?? "",
                        play.opponentJersey.map(String.init) ?? "",
                        play.playType.rawValue,
                        play.evaluation.rawValue,
                        play.serveType?.rawValue ?? "",
                        play.receptionQuality?.rawValue ?? "",
                        play.attackCourse?.rawValue ?? "",
                        play.isAssist ? "true" : "false",
                        isoFormatter.string(from: play.timestamp)
                    ].joined(separator: ","))
                }
            }
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }
}
