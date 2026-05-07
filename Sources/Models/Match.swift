// Match — 試合エンティティ

import Foundation

public struct Match: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var teamId: UUID
    public var recorderId: UUID
    public var matchCode: String
    public var matchCodeExpiresAt: Date
    public var date: Date
    public var startTime: Date
    public var endTime: Date?
    public var opponentTeamName: String
    public var tournamentName: String?
    public var matchType: MatchType
    public var venue: String?
    public var status: MatchStatus
    public var members: [MatchMember]
    public var serviceOrders: [ServiceOrderEntry]
    public var sets: [MatchSet]
    /// 動画の「試合開始」位置 (秒)。動画未同期なら nil
    public var videoStartOffsetSeconds: Double?
    /// 動画ファイルのローカルパス (Documents 配下、相対パス)
    public var videoLocalPath: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        teamId: UUID,
        recorderId: UUID,
        matchCode: String,
        matchCodeExpiresAt: Date,
        date: Date,
        startTime: Date,
        endTime: Date? = nil,
        opponentTeamName: String,
        tournamentName: String? = nil,
        matchType: MatchType,
        venue: String? = nil,
        status: MatchStatus = .preparing,
        members: [MatchMember] = [],
        serviceOrders: [ServiceOrderEntry] = [],
        sets: [MatchSet] = [],
        videoStartOffsetSeconds: Double? = nil,
        videoLocalPath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.teamId = teamId
        self.recorderId = recorderId
        self.matchCode = matchCode
        self.matchCodeExpiresAt = matchCodeExpiresAt
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.opponentTeamName = opponentTeamName
        self.tournamentName = tournamentName
        self.matchType = matchType
        self.venue = venue
        self.status = status
        self.members = members
        self.serviceOrders = serviceOrders
        self.sets = sets
        self.videoStartOffsetSeconds = videoStartOffsetSeconds
        self.videoLocalPath = videoLocalPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum MatchType: String, Codable, CaseIterable, Sendable {
    case official        // 公式戦
    case practice        // 練習試合
    case trainingCamp    // 合宿
}

public enum MatchStatus: String, Codable, CaseIterable, Sendable {
    case preparing
    case inProgress
    case finished
    case abandoned
}
