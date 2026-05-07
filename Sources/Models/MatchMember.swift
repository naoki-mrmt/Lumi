// MatchMember — 試合メンバー（スタメン + 控え）

import Foundation

public struct MatchMember: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var matchId: UUID
    public var playerId: UUID
    public var isStarter: Bool

    public init(
        id: UUID = UUID(),
        matchId: UUID,
        playerId: UUID,
        isStarter: Bool
    ) {
        self.id = id
        self.matchId = matchId
        self.playerId = playerId
        self.isStarter = isStarter
    }
}
