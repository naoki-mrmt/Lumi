// Timeout — タイムアウト

import Foundation

public struct Timeout: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var setId: UUID
    public var ourScore: Int
    public var opponentScore: Int
    public var requestingTeam: Team.ServingSide
    public var timeoutType: TimeoutType
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        setId: UUID,
        ourScore: Int,
        opponentScore: Int,
        requestingTeam: Team.ServingSide,
        timeoutType: TimeoutType = .regular,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.setId = setId
        self.ourScore = ourScore
        self.opponentScore = opponentScore
        self.requestingTeam = requestingTeam
        self.timeoutType = timeoutType
        self.timestamp = timestamp
    }
}

public enum TimeoutType: String, Codable, CaseIterable, Sendable {
    case regular, medical
}

public extension MatchSet {
    /// 1セット最大タイムアウト回数 (各チーム)
    static let maxTimeoutsPerTeamPerSet: Int = 2
}
