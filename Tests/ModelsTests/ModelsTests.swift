import Testing
import Foundation
@testable import Models

@Suite("Player")
struct PlayerTests {
    @Test func defaultIsActive() {
        let player = Player(teamId: UUID(), jerseyNumber: 1, name: "山田")
        #expect(player.isActive == true)
    }

    @Test func codableRoundTrip() throws {
        let player = Player(
            id: UUID(),
            teamId: UUID(),
            jerseyNumber: 7,
            name: "鈴木",
            positionTendency: .hc,
            isActive: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let encoded = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: encoded)
        #expect(decoded == player)
    }
}

@Suite("Team")
struct TeamTests {
    @Test func maxPlayersIs15() {
        #expect(Team.maxPlayers == 15)
    }

    @Test func codableRoundTrip() throws {
        let team = Team(ownerId: UUID(), name: "Lumi")
        let data = try JSONEncoder().encode(team)
        let decoded = try JSONDecoder().decode(Team.self, from: data)
        #expect(decoded == team)
    }
}

@Suite("ServiceOrderEntry")
struct ServiceOrderEntryTests {
    @Test func totalIs9() {
        #expect(ServiceOrderEntry.total == 9)
    }

    @Test("currentPlayerId defaults to startingPlayerId")
    func currentPlayerIdDefault() {
        let starter = UUID()
        let entry = ServiceOrderEntry(matchId: UUID(), order: 1, startingPlayerId: starter)
        #expect(entry.currentPlayerId == starter)
    }

    @Test("next wraps from 9 to 1")
    func nextWraps() {
        #expect(ServiceOrderEntry.next(after: 1) == 2)
        #expect(ServiceOrderEntry.next(after: 8) == 9)
        #expect(ServiceOrderEntry.next(after: 9) == 1)
    }

    @Test("previous wraps from 1 to 9")
    func previousWraps() {
        #expect(ServiceOrderEntry.previous(before: 2) == 1)
        #expect(ServiceOrderEntry.previous(before: 1) == 9)
        #expect(ServiceOrderEntry.previous(before: 9) == 8)
    }
}

@Suite("MatchSet")
struct MatchSetTests {
    @Test func substitutionLimits() {
        #expect(MatchSet.maxSubstitutionsPerSet == 4)
        #expect(MatchSet.maxPlayersPerSubstitution == 3)
        #expect(MatchSet.maxSubstitutionsPerOrder == 2)
    }

    @Test func formationRawValue() {
        #expect(Formation.f5_1_3.rawValue == "5-1-3")
        #expect(Formation.f3_3_3.rawValue == "3-3-3")
    }
}

@Suite("Play")
struct PlayTests {
    @Test func defaultIsAssistFalse() {
        let p = Play(
            rallyId: UUID(),
            sequenceInRally: 1,
            playTeam: .own,
            playType: .attack,
            evaluation: .excellent
        )
        #expect(p.isAssist == false)
    }

    @Test func evaluationSymbol() {
        #expect(Evaluation.excellent.symbol == "◎")
        #expect(Evaluation.good.symbol == "○")
        #expect(Evaluation.normal.symbol == "△")
        #expect(Evaluation.error.symbol == "×")
    }

    @Test func playTypeAllCases() {
        #expect(PlayType.allCases.count == 7)
    }

    @Test func codableRoundTrip() throws {
        let p = Play(
            rallyId: UUID(),
            sequenceInRally: 3,
            playTeam: .own,
            playerId: UUID(),
            playType: .attack,
            evaluation: .excellent,
            attackCourse: .cross,
            courtZone: CourtZone(row: 1, col: 2, side: .opponent)
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Play.self, from: data)
        #expect(decoded == p)
    }

    @Test func courtZoneIndex() {
        let z = CourtZone(row: 1, col: 2, side: .own)
        #expect(z.index == 5)
    }
}

@Suite("Timeout")
struct TimeoutTests {
    @Test func maxTimeoutsPerTeamPerSet() {
        #expect(MatchSet.maxTimeoutsPerTeamPerSet == 2)
    }

    @Test func codableRoundTrip() throws {
        let t = Timeout(setId: UUID(), ourScore: 5, opponentScore: 3, requestingTeam: .own)
        let data = try JSONEncoder().encode(t)
        let decoded = try JSONDecoder().decode(Timeout.self, from: data)
        #expect(decoded == t)
    }
}

@Suite("Match")
struct MatchTests {
    @Test func defaultStatusIsPreparing() {
        let m = Match(
            teamId: UUID(),
            recorderId: UUID(),
            matchCode: "ABC123",
            matchCodeExpiresAt: Date(),
            date: Date(),
            startTime: Date(),
            opponentTeamName: "対戦相手",
            matchType: .practice
        )
        #expect(m.status == .preparing)
        #expect(m.members.isEmpty)
        #expect(m.serviceOrders.isEmpty)
        #expect(m.sets.isEmpty)
    }

    @Test func matchTypeAllCases() {
        #expect(MatchType.allCases.count == 3)
    }
}
