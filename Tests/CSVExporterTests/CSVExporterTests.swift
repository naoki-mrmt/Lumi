import Testing
import Foundation
@testable import Models
@testable import CSVExporter

@Suite("CSVExporter")
struct CSVExporterTests {
    @Test("playerStatsCSV: ヘッダ + 9行 (スタメン)")
    func player_stats_format() {
        let match = makeMatch()
        let csv = CSVExporter.playerStatsCSV(match: match)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 10)
        #expect(String(lines[0]).hasPrefix("player_id,"))
    }

    @Test("playLogCSV: ヘッダ + プレー行")
    func play_log_format() {
        let match = makeMatch(plays: [
            Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playerId: UUID(), playType: .attack, evaluation: .excellent),
            Play(rallyId: UUID(), sequenceInRally: 2, playTeam: .opponent, opponentJersey: 7, playType: .attack, evaluation: .normal),
        ])
        let csv = CSVExporter.playLogCSV(match: match)
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3)  // header + 2 plays
        #expect(String(lines[0]).hasPrefix("set_number,"))
        #expect(String(lines[1]).contains("attack"))
    }

    private func makeMatch(plays: [Play] = []) -> Match {
        let teamId = UUID()
        let matchId = UUID()
        let setId = UUID()
        let starters = (0..<9).map { _ in UUID() }
        let serviceOrders = starters.enumerated().map {
            ServiceOrderEntry(matchId: matchId, order: $0.offset + 1, startingPlayerId: $0.element)
        }
        let rally = Rally(setId: setId, rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own, plays: plays)
        let set = MatchSet(id: setId, matchId: matchId, setNumber: 1, formation: .f5_1_3, rallies: [rally])
        return Match(
            id: matchId, teamId: teamId, recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: "X", matchType: .practice,
            serviceOrders: serviceOrders, sets: [set]
        )
    }
}
