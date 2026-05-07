// Play — ラリー内の1プレー記録

import Foundation

public struct Play: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var rallyId: UUID
    public var sequenceInRally: Int
    public var playTeam: Team.ServingSide
    public var playerId: UUID?
    public var opponentJersey: Int?
    public var playType: PlayType
    public var evaluation: Evaluation
    public var serveType: ServeType?
    public var serveAttempt: ServeAttempt?
    public var receptionQuality: ReceptionQuality?
    public var attackCourse: AttackCourse?
    /// 1..9 のサーブコース (相手陣ゾーン)
    public var serveCourse: Int?
    /// ブロック枚数 (1/2/3)
    public var blockCount: Int?
    public var errorType: ErrorType?
    public var courtZone: CourtZone?
    public var timestamp: Date
    public var videoOffsetSeconds: Double?
    public var isAssist: Bool

    public init(
        id: UUID = UUID(),
        rallyId: UUID,
        sequenceInRally: Int,
        playTeam: Team.ServingSide,
        playerId: UUID? = nil,
        opponentJersey: Int? = nil,
        playType: PlayType,
        evaluation: Evaluation,
        serveType: ServeType? = nil,
        serveAttempt: ServeAttempt? = nil,
        receptionQuality: ReceptionQuality? = nil,
        attackCourse: AttackCourse? = nil,
        serveCourse: Int? = nil,
        blockCount: Int? = nil,
        errorType: ErrorType? = nil,
        courtZone: CourtZone? = nil,
        timestamp: Date = Date(),
        videoOffsetSeconds: Double? = nil,
        isAssist: Bool = false
    ) {
        self.id = id
        self.rallyId = rallyId
        self.sequenceInRally = sequenceInRally
        self.playTeam = playTeam
        self.playerId = playerId
        self.opponentJersey = opponentJersey
        self.playType = playType
        self.evaluation = evaluation
        self.serveType = serveType
        self.serveAttempt = serveAttempt
        self.receptionQuality = receptionQuality
        self.attackCourse = attackCourse
        self.serveCourse = serveCourse
        self.blockCount = blockCount
        self.errorType = errorType
        self.courtZone = courtZone
        self.timestamp = timestamp
        self.videoOffsetSeconds = videoOffsetSeconds
        self.isAssist = isAssist
    }
}

public enum PlayType: String, Codable, CaseIterable, Sendable {
    case serve, reception, set, attack, block, dig, error
}

public enum Evaluation: String, Codable, CaseIterable, Sendable {
    case excellent  // ◎
    case good       // ○
    case normal     // △
    case error      // ×

    public var symbol: String {
        switch self {
        case .excellent: "◎"
        case .good: "○"
        case .normal: "△"
        case .error: "×"
        }
    }
}

public enum ServeType: String, Codable, CaseIterable, Sendable {
    case float, jump, jumpFloat
}

public enum ServeAttempt: String, Codable, CaseIterable, Sendable {
    case first, second
}

public enum ReceptionQuality: String, Codable, CaseIterable, Sendable {
    case aPass, bPass, cPass, dPass
}

public enum AttackCourse: String, Codable, CaseIterable, Sendable {
    case cross, straight, inner, feint, other
}

public enum ErrorType: String, Codable, CaseIterable, Sendable {
    case dribble, overTimes, touchNet, fourHits, footFault, netInServe, other
}

public struct CourtZone: Equatable, Hashable, Codable, Sendable {
    public var row: Int   // 0..2
    public var col: Int   // 0..2
    public var side: Side

    public enum Side: String, Codable, Sendable {
        case own, opponent
    }

    public init(row: Int, col: Int, side: Side) {
        self.row = row
        self.col = col
        self.side = side
    }

    /// 0..8 のフラットインデックス
    public var index: Int { row * 3 + col }
}
