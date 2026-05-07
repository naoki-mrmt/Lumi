// MultiTeam — 複数チーム管理 (Phase 2.4)

import Foundation

public struct UserProfile: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var email: String?
    public var displayName: String
    public var teamIds: [UUID]            // 所属チーム
    public var primaryTeamId: UUID?       // メインチーム
    public var createdAt: Date

    public init(
        id: UUID,
        email: String? = nil,
        displayName: String,
        teamIds: [UUID] = [],
        primaryTeamId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.teamIds = teamIds
        self.primaryTeamId = primaryTeamId
        self.createdAt = createdAt
    }
}
