// Player — 選手エンティティ

import Foundation

public struct Player: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var teamId: UUID
    public var jerseyNumber: Int
    public var name: String
    public var positionTendency: PositionTendency?
    public var isActive: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        teamId: UUID,
        jerseyNumber: Int,
        name: String,
        positionTendency: PositionTendency? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teamId = teamId
        self.jerseyNumber = jerseyNumber
        self.name = name
        self.positionTendency = positionTendency
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

public enum PositionTendency: String, Codable, CaseIterable, Sendable {
    case fl, fc, fr
    case hl, hc, hr
    case bl, bc, br
    case custom
}
