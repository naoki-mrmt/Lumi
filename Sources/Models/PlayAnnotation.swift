// PlayAnnotation — ラリー単位コメント / プレーへのアノテーション (Phase 2.2)

import Foundation

public struct PlayAnnotation: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var rallyId: UUID
    public var playId: UUID?     // ラリー全体なら nil
    public var authorId: UUID
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        rallyId: UUID,
        playId: UUID? = nil,
        authorId: UUID,
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.rallyId = rallyId
        self.playId = playId
        self.authorId = authorId
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
