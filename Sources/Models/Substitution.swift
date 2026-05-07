// Substitution — 選手交代

import Foundation

public struct Substitution: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var setId: UUID
    public var ourScore: Int
    public var opponentScore: Int
    public var playerInId: UUID
    public var playerOutId: UUID
    public var serviceOrderId: UUID
    /// このセット内で何回目の交代か (1〜4)
    public var substitutionCountInSet: Int
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        setId: UUID,
        ourScore: Int,
        opponentScore: Int,
        playerInId: UUID,
        playerOutId: UUID,
        serviceOrderId: UUID,
        substitutionCountInSet: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.setId = setId
        self.ourScore = ourScore
        self.opponentScore = opponentScore
        self.playerInId = playerInId
        self.playerOutId = playerOutId
        self.serviceOrderId = serviceOrderId
        self.substitutionCountInSet = substitutionCountInSet
        self.timestamp = timestamp
    }
}
