// Team — チームエンティティ

import Foundation

public struct Team: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var ownerId: UUID
    public var name: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        ownerId: UUID,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Team {
    /// サーブ権を持っているチーム側
    public enum ServingSide: String, Codable, Sendable {
        case own
        case opponent
    }
}

extension Team {
    /// チームあたり最大選手数
    public static let maxPlayers: Int = 15
}
