// Rally — ラリー (M1では最小限の構造のみ。M2 で拡張)

import Foundation

public struct Rally: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var setId: UUID
    public var rallyNumber: Int
    public var startScoreUs: Int
    public var startScoreOpp: Int
    public var servingTeam: Team.ServingSide
    /// 自軍サーブ時のサーバー (相手サーブ時は nil)
    public var servingPlayerId: UUID?
    /// 相手サーブ時の背番号 (自軍サーブ時は nil)
    public var opponentServingJersey: Int?
    public var winner: Team.ServingSide?
    public var startedAt: Date
    public var endedAt: Date?
    public var plays: [Play]

    public init(
        id: UUID = UUID(),
        setId: UUID,
        rallyNumber: Int,
        startScoreUs: Int,
        startScoreOpp: Int,
        servingTeam: Team.ServingSide,
        servingPlayerId: UUID? = nil,
        opponentServingJersey: Int? = nil,
        winner: Team.ServingSide? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        plays: [Play] = []
    ) {
        self.id = id
        self.setId = setId
        self.rallyNumber = rallyNumber
        self.startScoreUs = startScoreUs
        self.startScoreOpp = startScoreOpp
        self.servingTeam = servingTeam
        self.servingPlayerId = servingPlayerId
        self.opponentServingJersey = opponentServingJersey
        self.winner = winner
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plays = plays
    }
}
